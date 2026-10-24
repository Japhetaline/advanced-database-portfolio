// =============================================================
// Retiro Resort — Portfolio 4: schema validation test
// The insert below is SUPPOSED TO FAIL (negative price, missing'available').
// =============================================================
try {
db.menu_items.insertOne({ name: "Free Plantain", category: "side", price:
-100 });
print("Inserted — validation did NOT work (unexpected)");
} catch (e) {
print("Rejected as expected: " + e.message);
if (e.errInfo) printjson(e.errInfo.details);
}