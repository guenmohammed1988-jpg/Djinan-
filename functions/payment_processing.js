const functions = require('firebase-functions/v2');
const admin = require('firebase-admin/app');

// Process CHARGILY payment
exports.processChargilyPayment = functions.https.onCall(async (data, context) => {
  const { userId, phoneNumber, amount, transactionId } = data;
  
  console.log(`Processing CHARGILY payment for user: ${userId}`);
  
  try {
    // Validate input
    if (!userId || !phoneNumber || !amount || !transactionId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    
    if (amount <= 0) {
      throw new functions.https.HttpsError('invalid-amount', 'Amount must be positive');
    }
    
    // Process payment through CHARGILY API
    const paymentData = {
      userId: userId,
      phoneNumber: phoneNumber,
      amount: amount,
      currency: 'DZD',
      transactionId: transactionId,
      provider: 'chargily',
      status: 'processing',
      processedAt: new Date().toISOString(),
    };
    
    // Store payment record
    const db = admin.firestore();
    await db.collection('payments').add({
      ...paymentData,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Update user subscription
    const subscriptionDoc = await db.collection('enhanced_subscriptions').doc(userId).get();
    if (subscriptionDoc.exists) {
      await subscriptionDoc.reference.update({
        lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
        totalPaid: admin.firestore.FieldValue.increment(amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    
    // Simulate CHARGILY processing (in real implementation, you'd integrate with CHARGILY API)
    const processingResult = await simulateChargilyProcessing(paymentData);
    
    if (processingResult.success) {
      // Update payment status to completed
      await db.collection('payments').doc(transactionId).update({
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return {
        success: true,
        message: 'Payment processed successfully',
        transactionId: transactionId,
        amount: amount,
        currency: 'DZD',
        processedAt: new Date().toISOString(),
      };
    } else {
      throw new functions.https.HttpsError('payment-failed', processingResult.error || 'Payment processing failed');
    }
  } catch (error) {
    console.error(`CHARGILY payment error: ${error}`);
    throw new functions.https.HttpsError('processing-error', error.message);
  }
});

// Process STRIPE payment
exports.processStripePayment = functions.https.onCall(async (data, context) => {
  const { userId, paymentIntentId, cardLast4, amount } = data;
  
  console.log(`Processing STRIPE payment for user: ${userId}`);
  
  try {
    // Validate input
    if (!userId || !paymentIntentId || !cardLast4 || !amount) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    
    if (amount <= 0) {
      throw new functions.https.HttpsError('invalid-amount', 'Amount must be positive');
    }
    
    // Process payment through STRIPE API
    const paymentData = {
      userId: userId,
      paymentIntentId: paymentIntentId,
      cardLast4: cardLast4,
      amount: amount,
      currency: 'DZD',
      provider: 'stripe',
      status: 'processing',
      processedAt: new Date().toISOString(),
    };
    
    // Store payment record
    const db = admin.firestore();
    await db.collection('payments').add({
      ...paymentData,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Update user subscription
    const subscriptionDoc = await db.collection('enhanced_subscriptions').doc(userId).get();
    if (subscriptionDoc.exists) {
      await subscriptionDoc.reference.update({
        lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
        totalPaid: admin.firestore.FieldValue.increment(amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    
    // Simulate STRIPE processing (in real implementation, you'd integrate with STRIPE SDK)
    const processingResult = await simulateStripeProcessing(paymentData);
    
    if (processingResult.success) {
      // Update payment status to completed
      await db.collection('payments').doc(paymentIntentId).update({
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return {
        success: true,
        message: 'Payment processed successfully',
        paymentIntentId: paymentIntentId,
        amount: amount,
        currency: 'DZD',
        processedAt: new Date().toISOString(),
      };
    } else {
      throw new functions.https.HttpsError('payment-failed', processingResult.error || 'Payment processing failed');
    }
  } catch (error) {
    console.error(`STRIPE payment error: ${error}`);
    throw new functions.https.HttpsError('processing-error', error.message);
  }
});

// Process PayPal payment
exports.processPayPalPayment = functions.https.onCall(async (data, context) => {
  const { userId, paymentId, payerId, amount } = data;
  
  console.log(`Processing PayPal payment for user: ${userId}`);
  
  try {
    // Validate input
    if (!userId || !paymentId || !payerId || !amount) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    
    if (amount <= 0) {
      throw new functions.https.HttpsError('invalid-amount', 'Amount must be positive');
    }
    
    // Process payment through PayPal API
    const paymentData = {
      userId: userId,
      paymentId: paymentId,
      payerId: payerId,
      amount: amount,
      currency: 'DZD',
      provider: 'paypal',
      status: 'processing',
      processedAt: new Date().toISOString(),
    };
    
    // Store payment record
    const db = admin.firestore();
    await db.collection('payments').add({
      ...paymentData,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Update user subscription
    const subscriptionDoc = await db.collection('enhanced_subscriptions').doc(userId).get();
    if (subscriptionDoc.exists) {
      await subscriptionDoc.reference.update({
        lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
        totalPaid: admin.firestore.FieldValue.increment(amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    
    // Simulate PayPal processing (in real implementation, you'd integrate with PayPal SDK)
    const processingResult = await simulatePayPalProcessing(paymentData);
    
    if (processingResult.success) {
      // Update payment status to completed
      await db.collection('payments').doc(paymentId).update({
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return {
        success: true,
        message: 'Payment processed successfully',
        paymentId: paymentId,
        amount: amount,
        currency: 'DZD',
        processedAt: new Date().toISOString(),
      };
    } else {
      throw new functions.https.HttpsError('payment-failed', processingResult.error || 'Payment processing failed');
    }
  } catch (error) {
    console.error(`PayPal payment error: ${error}`);
    throw new functions.https.HttpsError('processing-error', error.message);
  }
});

// Process BINANCE payment
exports.processBinancePayment = functions.https.onCall(async (data, context) => {
  const { userId, transactionHash, walletAddress, amount } = data;
  
  console.log(`Processing BINANCE payment for user: ${userId}`);
  
  try {
    // Validate input
    if (!userId || !transactionHash || !walletAddress || !amount) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    
    if (amount <= 0) {
      throw new functions.https.HttpsError('invalid-amount', 'Amount must be positive');
    }
    
    // Process payment through BINANCE API
    const paymentData = {
      userId: userId,
      transactionHash: transactionHash,
      walletAddress: walletAddress,
      amount: amount,
      currency: 'DZD',
      provider: 'binance',
      status: 'processing',
      processedAt: new Date().toISOString(),
    };
    
    // Store payment record
    const db = admin.firestore();
    await db.collection('payments').add({
      ...paymentData,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Update user subscription
    const subscriptionDoc = await db.collection('enhanced_subscriptions').doc(userId).get();
    if (subscriptionDoc.exists) {
      await subscriptionDoc.reference.update({
        lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
        totalPaid: admin.firestore.FieldValue.increment(amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    
    // Simulate BINANCE processing (in real implementation, you'd integrate with BINANCE SDK)
    const processingResult = await simulateBinanceProcessing(paymentData);
    
    if (processingResult.success) {
      // Update payment status to completed
      await db.collection('payments').doc(transactionHash).update({
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return {
        success: true,
        message: 'Payment processed successfully',
        transactionHash: transactionHash,
        amount: amount,
        currency: 'DZD',
        processedAt: new Date().toISOString(),
      };
    } else {
      throw new functions.https.HttpsError('payment-failed', processingResult.error || 'Payment processing failed');
    }
  } catch (error) {
    console.error(`BINANCE payment error: ${error}`);
    throw new functions.https.HttpsError('processing-error', error.message);
  }
});

// Update subscription expiry date
exports.updateSubscriptionExpiry = functions.https.onCall(async (data, context) => {
  const { userId, newExpiryDate, reason } = data;
  
  console.log(`Updating subscription expiry for user: ${userId}`);
  
  try {
    if (!userId || !newExpiryDate) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    
    // Update subscription expiry date
    const db = admin.firestore();
    await db.collection('enhanced_subscriptions').doc(userId).update({
      expiryDate: new Date(newExpiryDate),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Schedule expiry notification
    const notificationDate = new Date(newExpiryDate);
    notificationDate.setDate(notificationDate.getDate() - 30); // 30 days before expiry
    
    await db.collection('subscription_notifications').add({
      userId: userId,
      type: 'expiry_update',
      title: 'تحديث تاريخ الانتهاء',
      message: 'تم تحديث تاريخ انتهاء اشتراكك',
      newExpiryDate: new Date(newExpiryDate),
      scheduledFor: notificationDate.toISOString(),
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    return {
      success: true,
      message: 'Expiry date updated successfully',
      newExpiryDate: new Date(newExpiryDate),
      scheduledNotificationDate: notificationDate.toISOString(),
    };
  } catch (error) {
    console.error(`Expiry update error: ${error}`);
    throw new functions.https.HttpsError('update-error', error.message);
  }
});

// Send expiry notifications
exports.sendExpiryNotifications = functions.pubsub.schedule('0 9 * * *') // Daily at 9 AM
  .onRun(async (context) => {
    console.log('Running expiry notification check...');
    
    try {
      const db = admin.firestore();
      const now = new Date();
      
      // Find subscriptions expiring in next 30 days
      const thirtyDaysFromNow = new Date(now);
      thirtyDaysFromNow.setDate(thirtyDaysFromNow.getDate() + 30);
      
      const expiringSubscriptions = await db.collection('enhanced_subscriptions')
        .where('expiryDate', '<=', thirtyDaysFromNow)
        .where('expiryDate', '>', now)
        .get();
      
      if (!expiringSubscriptions.empty) {
        const batch = db.batch();
        
        for (const doc of expiringSubscriptions.docs) {
          const subscription = doc.data();
          const userId = subscription.userId;
          
          // Send notification
          await db.collection('subscription_notifications').add({
            userId: userId,
            type: 'expiry_reminder',
            title: 'انتهاء الاشتراك قريباً',
            message: 'سينتهي اشتراكك خلال 30 يوم',
            expiryDate: subscription.expiryDate,
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        
        await batch.commit();
        
        console.log(`Sent ${expiringSubscriptions.size} expiry notifications`);
      }
      
      return {
        success: true,
        message: 'Expiry notifications sent successfully',
        notificationsSent: expiringSubscriptions.size,
      };
    } catch (error) {
      console.error(`Expiry notification error: ${error}`);
      return {
        success: false,
        message: error.message,
      };
    }
  }
});

// Helper functions for payment processing simulation
async function simulateChargilyProcessing(paymentData) {
  // Simulate CHARGILY payment processing
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({
        success: true,
        message: 'Payment processed via CHARGILY',
        transactionId: `CHG_${Date.now().getTime()}`,
      });
    }, 2000); // 2 second delay
  });
}

async function simulateStripeProcessing(paymentData) {
  // Simulate STRIPE payment processing
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({
        success: true,
        message: 'Payment processed via STRIPE',
        paymentIntentId: `pi_${Date.now().getTime()}`,
      });
    }, 3000); // 3 second delay
  });
}

async function simulatePayPalProcessing(paymentData) {
  // Simulate PayPal payment processing
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({
        success: true,
        message: 'Payment processed via PayPal',
        paymentId: `PP_${Date.now().getTime()}`,
      });
    }, 2500); // 2.5 second delay
  });
}

async function simulateBinanceProcessing(paymentData) {
  // Simulate BINANCE payment processing
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve({
        success: true,
        message: 'Payment processed via BINANCE',
        transactionHash: `BN_${Date.now().getTime()}`,
      });
    }, 4000); // 4 second delay
  });
}
