const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore"); // 🚀 NEW TRIGGER
const admin = require("firebase-admin");

admin.initializeApp();

// -----------------------------------------------------------------
// 1. 🕛 THE MIDNIGHT AUTO-CLEANER (Aapka Purana Solid Logic)
// -----------------------------------------------------------------
exports.midnightAutoCleaner = onSchedule({
    schedule: "0 0 * * *",
    timeZone: "Asia/Kolkata",
}, async (event) => {
    const db = admin.firestore();
    console.log("🕛 Midnight Auto-Cleaner Started...");

    const pendingQuery = await db.collection("orders")
        .where("exitStatus", "in", ["PENDING", "READY_FOR_EXIT"])
        .get();

    if (pendingQuery.empty) {
        console.log("✅ No pending orders found. System Clean!");
        return null;
    }

    const batch = db.batch();
    let count = 0;

    pendingQuery.forEach((doc) => {
        const data = doc.data();
        const docRef = db.collection("orders").doc(doc.id);

        batch.update(docRef, {
            exitStatus: "EXPIRED_BY_SYSTEM", 
            qrConsumed: true,                
            qrExpiresAt: admin.firestore.FieldValue.serverTimestamp(), 
            isDeleted: true,                 
            wasEverRejected: true,           
            systemRemark: "AUTO_MIDNIGHT_EXPIRE",
            originalStatusSnapshot: data.paymentStatus || 'UNKNOWN',
            archivedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        count++;
    });

    await batch.commit();
    console.log(`🧹 FORENSIC SWEEP COMPLETE: ${count} junk orders moved to Black Box.`);
    return null;
});

// -----------------------------------------------------------------
// 2. 🚀 THE REALTIME NOTIFICATION ENGINE (Raj Aagya)
// -----------------------------------------------------------------
exports.sendOrderStatusNotification = onDocumentUpdated("orders/{orderId}", async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    let title = "";
    let body = "";

    // 🎯 LOGIC 1: GUARD APPROVES
    if (beforeData.exitStatus !== "APPROVED" && afterData.exitStatus === "APPROVED") {
        title = "✅ Exit Approved";
        body = "Your Gate Pass has been verified. You may leave safely. Thank you for using ClickOut!";
    } 
    // 🎯 LOGIC 2: GUARD REJECTS
    else if (beforeData.exitStatus !== "REJECTED" && afterData.exitStatus === "REJECTED") {
        title = "❌ Exit Stopped";
        body = "Please fix your cart. Reason: " + (afterData.rejectReason || "Item Mismatch detected.");
    } 
    // 🎯 LOGIC 3: CASHIER VERIFIES PAYMENT
    else if (beforeData.paymentStatus !== "PAID" && afterData.paymentStatus === "PAID") {
        title = "💰 Payment Verified";
        body = "Your payment was successful. Your Gate Pass is ready for exit!";
    }

    // Agar koi relevant change nahi hua, toh kuch mat karo (Idempotency)
    if (!title) {
        return null;
    }

    const db = admin.firestore();
    const userId = afterData.userId;

    if (!userId) {
        console.log("No userId found in order.");
        return null;
    }

    // User ka data nikalo FCM token ke liye
    const userDoc = await db.collection("users").doc(userId).get();
    
    if (!userDoc.exists) {
        console.log("User not found.");
        return null;
    }

    const userData = userDoc.data();
    const tokens = userData.fcmTokens;

    if (!tokens || tokens.length === 0) {
        console.log(`No FCM tokens found for user ${userId}`);
        return null;
    }

    // Message payload banao
    const message = {
        notification: {
            title: title,
            body: body,
        },
        data: {
            orderId: event.params.orderId,
            exitStatus: afterData.exitStatus || "",
            click_action: "FLUTTER_NOTIFICATION_CLICK" // Deep linking ke liye aage kaam aayega
        },
        tokens: tokens, // Ek saath saari devices par jayega!
    };

    try {
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`Successfully sent ${response.successCount} messages for order ${event.params.orderId}`);
        
        // Pro-tip cleanup: Remove expired tokens here if needed
        if (response.failureCount > 0) {
            console.log(`Failed to send ${response.failureCount} messages.`);
        }
    } catch (error) {
        console.error("Error sending notification:", error);
    }

    return null;
});