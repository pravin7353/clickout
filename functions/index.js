const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore"); 
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onRequest } = require("firebase-functions/v2/https");
const crypto = require("crypto");
const admin = require("firebase-admin");

admin.initializeApp();

// -----------------------------------------------------------------
// 1. 🕛 THE MIDNIGHT AUTO-CLEANER 
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
// 2. 🚀 THE REALTIME NOTIFICATION ENGINE 
// -----------------------------------------------------------------
exports.sendOrderStatusNotification = onDocumentUpdated("orders/{orderId}", async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    let title = "";
    let body = "";

    if (beforeData.exitStatus !== "APPROVED" && afterData.exitStatus === "APPROVED") {
        title = "✅ Exit Approved";
        body = "Your Gate Pass has been verified. You may leave safely. Thank you for using ClickOut!";
    } 
    else if (beforeData.exitStatus !== "REJECTED" && afterData.exitStatus === "REJECTED") {
        title = "❌ Exit Stopped";
        body = "Please fix your cart. Reason: " + (afterData.rejectReason || "Item Mismatch detected.");
    } 
    else if (beforeData.paymentStatus !== "PAID" && afterData.paymentStatus === "PAID") {
        title = "💰 Payment Verified";
        body = "Your payment was successful. Your Gate Pass is ready for exit!";
    }

    if (!title) return null;

    const db = admin.firestore();
    const userId = afterData.userId;

    if (!userId) return null;

    const userDoc = await db.collection("users").doc(userId).get();
    
    if (!userDoc.exists) return null;

    const userData = userDoc.data();
    const tokens = userData.fcmTokens;

    if (!tokens || tokens.length === 0) return null;

    const message = {
        notification: { title: title, body: body },
        data: {
            orderId: event.params.orderId,
            exitStatus: afterData.exitStatus || "",
            click_action: "FLUTTER_NOTIFICATION_CLICK" 
        },
        tokens: tokens, 
    };

    try {
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`Successfully sent ${response.successCount} messages for order ${event.params.orderId}`);
    } catch (error) {
        console.error("Error sending notification:", error);
    }

    return null;
});

// -----------------------------------------------------------------
// 3. 🔐 SECURE MULTI-TENANT PAYMENT PAYLOAD GENERATOR (S2S)
// -----------------------------------------------------------------
exports.generatePaymentPayload = onCall(async (request) => {
    const { orderId, amount, gateway, tenantId } = request.data;
    const db = admin.firestore();
    
    if (!orderId || !amount || !gateway || !tenantId) {
        throw new HttpsError('invalid-argument', 'Missing parameters. Tenant ID is strictly required.');
    }

    // 🚀 SAAS MAGIC: Fetching Store's Specific API Keys from Firestore
    let gatewayKeys = {};
    try {
        const tenantDoc = await db.collection('tenants').doc(tenantId).get();
        if (!tenantDoc.exists) throw new Error("Tenant not found!");
        
        const config = tenantDoc.data().paymentConfig;
        if (!config || !config[gateway]) throw new Error(`Gateway ${gateway} not configured for this store.`);
        
        gatewayKeys = config[gateway]; // { merchantId, saltKey, saltIndex } OR { keyId, keySecret }
    } catch (e) {
        console.error(`SaaS Error for Tenant ${tenantId}:`, e.message);
        throw new HttpsError('permission-denied', 'Store payment gateway is not configured properly.');
    }

    if (gateway === 'PHONEPE') {
        const amountInPaise = Math.round(amount * 100);
        
        const requestBody = {
            merchantId: gatewayKeys.merchantId, // 🔓 DYNAMIC MERCH ID
            merchantTransactionId: orderId,
            merchantUserId: request.auth ? request.auth.uid : "GUEST_USER",
            amount: amountInPaise,
            callbackUrl: `https://us-central1-${process.env.GCLOUD_PROJECT}.cloudfunctions.net/paymentWebhook`, 
            mobileNumber: "9999999999",
            paymentInstrument: { type: "PAY_PAGE" }
        };

        const base64Body = Buffer.from(JSON.stringify(requestBody)).toString('base64');
        const crypto = require("crypto");
        const stringToHash = base64Body + "/pg/v1/pay" + gatewayKeys.saltKey; // 🔓 DYNAMIC SALT
        const sha256 = crypto.createHash('sha256').update(stringToHash).digest('hex');
        const checksum = `${sha256}###${gatewayKeys.saltIndex}`;

        return { base64Body, checksum, merchantId: gatewayKeys.merchantId };
    }

    if (gateway === 'RAZORPAY') {
        const amountInPaise = Math.round(amount * 100);
        // 🔓 DYNAMIC RAZORPAY KEYS
        const auth = Buffer.from(`${gatewayKeys.keyId}:${gatewayKeys.keySecret}`).toString('base64');

        try {
             const response = await fetch('https://api.razorpay.com/v1/orders', {
                method: 'POST',
                headers: {
                    'Authorization': `Basic ${auth}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    amount: amountInPaise,
                    currency: "INR",
                    receipt: orderId
                })
            });
            const rzpOrder = await response.json();
            
            if (rzpOrder.error) {
                throw new Error(rzpOrder.error.description);
            }

            return {
                key: gatewayKeys.keyId, 
                razorpayOrderId: rzpOrder.id 
            };
        } catch (error) {
            console.error("Razorpay Generation Error:", error);
            throw new HttpsError('internal', `Razorpay Error: ${error.message}`);
        }
    }

    throw new HttpsError('unimplemented', 'Gateway not supported');
});

// -----------------------------------------------------------------
// 4. 🚨 WEBHOOK: MULTI-GATEWAY PAYMENT VERIFIER
// -----------------------------------------------------------------
exports.paymentWebhook = onRequest(async (req, res) => {
    try {
        const db = admin.firestore();
        
        let orderId = null;
        let isSuccess = false;

        // 🧠 LOGIC: Identify which Gateway sent the webhook
        if (req.body.response) {
            // PHONEPE WEBHOOK (Base64 Encoded)
            const decodedStr = Buffer.from(req.body.response, 'base64').toString('utf8');
            const data = JSON.parse(decodedStr);
            orderId = data.data.merchantTransactionId;
            isSuccess = (data.success === true && data.data.state === 'COMPLETED');
            
        } else if (req.body.event === "payment.captured") {
            // RAZORPAY WEBHOOK (JSON Plain text)
            // Note: Make sure to set Razorpay webhook endpoint to this same URL
            const paymentPayload = req.body.payload.payment.entity;
            orderId = paymentPayload.notes.orderId || paymentPayload.order_id; // Check receipt or notes mapped ID
            isSuccess = (paymentPayload.status === 'captured');
        } else {
             return res.status(400).send("Unsupported Webhook Format");
        }

        if (!orderId) {
            return res.status(400).send("Missing Order ID");
        }

        // 🔒 UPDATE FIRESTORE ONLY IF GATEWAY CONFIRMS SUCCESS
        if (isSuccess) {
            await db.collection('orders').doc(orderId).update({
                paymentStatus: 'PAID',
                exitStatus: 'READY_FOR_EXIT', 
                paymentCompletedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            console.log(`✅ Webhook Confirmed: Order ${orderId} is securely PAID!`);
        } else {
            console.log(`❌ Webhook Alert: Payment pending/failed for Order ${orderId}`);
        }
        
        res.status(200).send("OK");
        
    } catch(e) {
        console.error("🚨 Webhook Critical Error:", e);
        res.status(500).send("Internal Server Error");
    }
});