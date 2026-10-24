// =============================================================
// Retiro Resort — Portfolio 4: queries, updates, aggregation, indexes
// Run (Terminal, from the repo root, with the retiro-mongo container running):
//   docker exec -it retiro-mongo mongosh mongodb://localhost:27017/retiro /scripts/02_queries.js
// =============================================================

print("\n=== Q1. Menu items where the guest chooses a protein (query inside a nested field) ===");
printjson(db.menu_items.find(
  { "options.protein": { $exists: true } },
  { _id: 0, name: 1, "options.protein": 1 }
).toArray());

print("\n=== Q2. Available vegetarian items under N5,000, cheapest first ===");
printjson(db.menu_items.find(
  { dietary_tags: "vegetarian", available: true, price: { $lt: 5000 } },
  { _id: 0, name: 1, price: 1 }
).sort({ price: 1 }).toArray());

print("\n=== Q3. UPDATE: orange juice is back in stock, and gains a new option ===");
db.menu_items.updateOne(
  { _id: "orange_juice" },
  { $set: { available: true, "options.ice": [true, false] } }
);
printjson(db.menu_items.findOne({ _id: "orange_juice" }));

print("\n=== Q4. Guests whose profile says vegetarian (for the kitchen) ===");
printjson(db.guest_profiles.find(
  { "preferences.dietary": "vegetarian" },
  { _id: 1, name: 1, "preferences.dietary": 1 }
).toArray());

print("\n=== Q5. AGGREGATION: average rating and number of reviews per year ===");
printjson(db.reviews.aggregate([
  { $group: { _id: { $year: "$created_at" },
              avg_rating: { $avg: "$rating" },
              reviews: { $sum: 1 } } },
  { $project: { _id: 0, year: "$_id", reviews: 1, avg_rating: { $round: ["$avg_rating", 2] } } },
  { $sort: { year: 1 } }
]).toArray());

print("\n=== Q6. AGGREGATION: most common complaint tags in 1-2 star reviews ===");
printjson(db.reviews.aggregate([
  { $match: { rating: { $lte: 2 } } },
  { $unwind: "$tags" },
  { $group: { _id: "$tags", times: { $sum: 1 } } },
  { $sort: { times: -1 } },
  { $limit: 5 }
]).toArray());

print("\n=== Q7. $lookup: real reviews joined with the guest's profile (like a SQL JOIN) ===");
printjson(db.reviews.aggregate([
  { $match: { booking_id: { $lt: 100000 } } },
  { $lookup: { from: "guest_profiles", localField: "guest_id", foreignField: "_id", as: "guest" } },
  { $unwind: "$guest" },
  { $project: { _id: 0, rating: 1, comment: 1, guest: "$guest.name.first", tier: "$guest.loyalty.tier" } }
]).toArray());

// ---------- Indexing and explain() — links back to Portfolio 2 ----------
function planSummary(label, exp) {
  const plan = JSON.stringify(exp.queryPlanner.winningPlan);
  const s = exp.executionStats;
  print(label + ": " + (plan.includes("IXSCAN") ? "IXSCAN (index used)" : "COLLSCAN (every document read)")
    + " | documents examined: " + s.totalDocsExamined
    + " | returned: " + s.nReturned
    + " | time: " + s.executionTimeMillis + " ms");
}

const recentFiveStars = { rating: 5, created_at: { $gte: ISODate("2026-01-01") } };

print("\n=== Q8. explain() BEFORE index: 5-star reviews since Jan 2026 ===");
db.reviews.dropIndexes(); // remove our index if the script is re-run (keeps _id index)
planSummary("Before", db.reviews.find(recentFiveStars).explain("executionStats"));

db.reviews.createIndex({ rating: 1, created_at: -1 }); // equality field first, then range
print("Created index { rating: 1, created_at: -1 }");
planSummary("After ", db.reviews.find(recentFiveStars).explain("executionStats"));

print("\nIndexes on reviews:");
printjson(db.reviews.getIndexes().map(i => i.name));
