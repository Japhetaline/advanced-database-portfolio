// =============================================================
// Retiro Resort — Portfolio 4: MongoDB collections with validation
// Run (Terminal, from the repo root, with the retiro-mongo container running):
//   docker exec -it retiro-mongo mongosh mongodb://localhost:27017/retiro /scripts/01_setup.js
// =============================================================

// Start clean so the script can be re-run
db.menu_items.drop();
db.guest_profiles.drop();
db.reviews.drop();

// ---------- 1. MENU ITEMS: every item has different options ----------
// $jsonSchema = rules MongoDB checks on every insert/update (schema validation)
db.createCollection("menu_items", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["name", "category", "price", "available"],
      properties: {
        name: { bsonType: "string", description: "item name is required" },
        category: { enum: ["local", "continental", "drink", "side"] },
        price: { bsonType: ["int", "double"], minimum: 1, description: "price in naira, must be > 0" },
        available: { bsonType: "bool" },
        options: { bsonType: "object", description: "free-form: differs per item" },
        dietary_tags: { bsonType: "array", items: { bsonType: "string" } }
      }
    }
  }
});

db.menu_items.insertMany([
  { _id: "akara_pap", name: "Akara and Pap", category: "local", price: 3500, available: true,
    options: { pap_type: ["white", "yellow"], extra_akara: { price: 500 } },
    dietary_tags: ["vegetarian"] },
  { _id: "yam_egg", name: "Yam and Egg Sauce", category: "local", price: 4500, available: true,
    options: { yam_style: ["boiled", "fried"], spice_level: ["mild", "hot"] },
    dietary_tags: ["vegetarian", "gluten-free"] },
  { _id: "jollof_plate", name: "Jollof Breakfast Plate", category: "local", price: 5000, available: true,
    options: { protein: ["chicken", "fish", "egg"], spice_level: ["mild", "hot"] },
    dietary_tags: ["gluten-free"] },
  { _id: "full_english", name: "Full English Breakfast", category: "continental", price: 7500, available: true,
    options: { eggs: ["fried", "scrambled", "poached"], toast: ["white", "brown"], protein: ["sausage", "bacon"] },
    dietary_tags: [] },
  { _id: "pancakes", name: "Pancakes with Honey", category: "continental", price: 4000, available: true,
    options: { topping: ["honey", "syrup", "fruit"] },
    dietary_tags: ["vegetarian"] },
  { _id: "fruit_platter", name: "Fruit Platter", category: "side", price: 3000, available: true,
    dietary_tags: ["vegan", "gluten-free"] }, // no options at all
  { _id: "tea", name: "Tea", category: "drink", price: 1500, available: true,
    options: { milk: ["none", "regular", "soy"], sugar: true },
    dietary_tags: ["vegetarian"] },
  { _id: "coffee", name: "Coffee", category: "drink", price: 2000, available: true,
    options: { style: ["black", "latte", "cappuccino"] },
    dietary_tags: ["vegetarian"] },
  { _id: "orange_juice", name: "Fresh Orange Juice", category: "drink", price: 2500, available: false,
    options: { size: { regular: 2500, large: 3500 } },
    dietary_tags: ["vegan"] }
]);

// ---------- 2. GUEST PROFILES: one document = everything about a guest ----------
// Preferences are EMBEDDED (always read with the guest).
// recent_stays REFERENCES PostgreSQL booking_ids and keeps only the last few,
// because a guest's full history grows without limit (16 MB document cap).
db.guest_profiles.insertMany([
  { _id: 1, name: { first: "Adaeze", last: "Okafor" }, email: "adaeze.okafor@example.com",
    preferences: { room: "garden view", pillow: "firm", dietary: ["no pork"], breakfast_time: "07:30" },
    loyalty: { tier: "gold", total_stays: 2 },
    recent_stays: [
      { booking_id: 1, room: "101", check_in: ISODate("2026-10-02") },
      { booking_id: 11, room: "C3", check_in: ISODate("2026-12-23") }
    ] },
  { _id: 3, name: { first: "Kofi", last: "Mensah" }, email: "kofi.mensah@example.com",
    preferences: { room: "sea view", dietary: ["vegetarian"], extra_bed: true },
    loyalty: { tier: "silver", total_stays: 1 },
    recent_stays: [
      { booking_id: 3, room: "301", check_in: ISODate("2026-10-09") }
    ] },
  { _id: 4, name: { first: "Sarah", last: "Williams" }, email: "sarah.williams@example.com",
    preferences: { room: "beach chalet", dietary: ["gluten-free"], airport_pickup: { needed: true, flight: "BA75" } },
    loyalty: { tier: "silver", total_stays: 1 },
    recent_stays: [
      { booking_id: 4, room: "C1", check_in: ISODate("2026-10-10") }
    ] }
]);

// ---------- 3. REVIEWS: flexible text, tags and staff replies ----------
db.reviews.insertMany([
  { booking_id: 1, guest_id: 1, rating: 5, created_at: ISODate("2026-10-05"),
    comment: "Lovely garden view and the akara was perfect.", tags: ["food", "view"],
    staff_responses: [ { staff: "Sola Hassan", text: "Thank you, Adaeze!", at: ISODate("2026-10-06") } ] },
  { booking_id: 3, guest_id: 3, rating: 4, created_at: ISODate("2026-10-12"),
    comment: "Great suite. Breakfast arrived 15 minutes late.", tags: ["room", "breakfast-delay"] },
  { booking_id: 4, guest_id: 4, rating: 5, created_at: ISODate("2026-10-14"),
    comment: "The beach chalet is worth every naira.", tags: ["room", "beach", "value"] }
]);

// Add 5,000 synthetic reviews so indexes and explain() have something to work on
const tagPool = ["food", "room", "beach", "staff", "value", "breakfast-delay", "noise", "wifi", "pool"];
const bulk = [];
for (let i = 0; i < 5000; i++) {
  bulk.push({
    booking_id: 100000 + i,
    guest_id: 1 + (i % 3000),
    rating: 1 + (Math.floor(i / 5) % 5),
    created_at: new Date(Date.UTC(2022 + (i % 5), i % 12, 1 + (i % 28))),
    comment: "Synthetic review " + i,
    tags: [tagPool[i % tagPool.length], tagPool[(i * 7) % tagPool.length]]
  });
}
db.reviews.insertMany(bulk);

print("menu_items: " + db.menu_items.countDocuments());
print("guest_profiles: " + db.guest_profiles.countDocuments());
print("reviews: " + db.reviews.countDocuments());
