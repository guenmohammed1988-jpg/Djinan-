const functions = require('firebase-functions/v2');
const admin = require('firebase-admin/app');
const { Storage } = require('@google-cloud/storage');

// Content moderation with Google Vision API
exports.analyzeContent = functions.https.onCall(async (data, context) => {
  const { contentId, userId, imageUrl, videoUrl, text } = data;
  
  console.log(`Analyzing content: ${contentId}`);
  
  try {
    // Validate input
    if (!contentId || !userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    
    if (!imageUrl && !videoUrl && !text) {
      throw new functions.https.HttpsError('invalid-argument', 'No content provided for analysis');
    }
    
    // Prepare Vision API request
    const visionApiKey = process.env.GOOGLE_VISION_API_KEY;
    const visionUrl = `https://vision.googleapis.com/v1/images:annotate?key=${visionApiKey}`;
    
    let requestBody = {
      requests: []
    };
    
    // Add image analysis if provided
    if (imageUrl) {
      requestBody.requests.push({
        image: {
          source: {
            imageUri: imageUrl,
          },
        },
        features: [
          'SAFE_SEARCH',
          'LABEL_DETECTION',
          'WEB_DETECTION',
          'OBJECT_LOCALIZATION',
          'EXPLICIT_CONTENT_DETECTION',
          'ADULT_CONTENT_DETECTION',
          'VIOLENCE_DETECTION',
          'RACY_DETECTION',
          'MEDICAL_DETECTION',
          'SPOOF_DETECTION',
          'WEAPON_DETECTION',
          'DRUG_DETECTION',
          'ALCOHOL_DETECTION',
        ],
      });
    }
    
    // Add text analysis if provided
    if (text) {
      requestBody.requests.push({
        text: {
          text: text,
        },
        features: [
          'SAFE_SEARCH',
          'LABEL_DETECTION',
          'EXPLICIT_CONTENT_DETECTION',
          'ADULT_CONTENT_DETECTION',
          'VIOLENCE_DETECTION',
          'RACY_DETECTION',
          'MEDICAL_DETECTION',
          'SPOOF_DETECTION',
        ],
      });
    }
    
    // Add video analysis if provided
    if (videoUrl) {
      requestBody.requests.push({
        video: {
          source: {
            videoUri: videoUrl,
          },
        },
        features: [
          'SAFE_SEARCH',
          'LABEL_DETECTION',
          'EXPLICIT_CONTENT_DETECTION',
          'ADULT_CONTENT_DETECTION',
          'VIOLENCE_DETECTION',
          'RACY_DETECTION',
          'MEDICAL_DETECTION',
          'SPOOF_DETECTION',
          'WEAPON_DETECTION',
          'DRUG_DETECTION',
          'ALCOHOL_DETECTION',
        ],
      });
    }
    
    // Make API request
    const response = await fetch(visionUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(requestBody),
    });
    
    if (!response.ok) {
      throw new functions.https.HttpsError('vision-api-error', 'Failed to analyze content');
    }
    
    const responseData = await response.json();
    const responses = responseData.responses;
    
    if (!responses || responses.length === 0) {
      throw new functions.https.HttpsError('vision-api-error', 'No analysis results');
    }
    
    const analysis = responses[0];
    
    // Determine content safety and appropriateness
    const isExplicit = analysis.explicitAnnotation?.includes('VERY_LIKELY') || false;
    const isAdult = analysis.adult?.includes('VERY_LIKELY') || false;
    const isViolent = analysis.violence?.includes('VERY_LIKELY') || false;
    const isRacy = analysis.racy?.includes('VERY_LIKELY') || false;
    const isWeapon = analysis.weapon?.includes('VERY_LIKELY') || false;
    const isDrug = analysis.drug?.includes('VERY_LIKELY') || false;
    const isMedical = analysis.medical?.includes('VERY_LIKELY') || false;
    const isSpoof = analysis.spoof?.includes('VERY_LIKELY') || false;
    const isHate = analysis.hate?.includes('VERY_LIKELY') || false;
    
    // Extract labels and entities
    const labels = analysis.labelAnnotations?.map(label => label.description || '').filter(label => label) || [];
    const detectedObjects = analysis.localizedObjectAnnotations?.map(obj => ({
      name: obj.name || '',
      boundingPoly: obj.boundingPoly?.vertices || [],
      score: obj.score || 0,
      type: _getObjectType(obj.name || ''),
    })) || [];
    
    const detectedText = analysis.textAnnotations?.map(text => text.description || '') || [];
    const detectedFaces = analysis.faceAnnotations?.map(face => ({
      confidence: face.confidence || 0,
      boundingPoly: face.boundingPoly?.vertices || [],
      role: face.role || '',
      joy: face.joy || '',
      sorrow: face.sorrow || '',
      anger: face.anger || '',
      surprise: face.surprise || '',
    })) || [];
    
    const detectedLogos = analysis.logoAnnotations?.map(logo => ({
      confidence: logo.confidence || 0,
      boundingPoly: logo.boundingPoly?.vertices || [],
      description: logo.description || '',
    })) || [];
    
    const detectedWebEntities = analysis.webDetection?.webEntities?.map(entity => entity.description || '') || [];
    const detectedUrls = analysis.webDetection?.pagesWithMatchingImages?.flatMap(page => 
      page.fullMatchingImages?.map(img => img.url || []) || []
    ) || [];
    
    // Determine if content should be flagged
    const shouldFlag = isExplicit || isAdult || isViolent || isWeapon || isDrug || isSpoof || isHate;
    
    // Calculate content safety score (0-100, lower is safer)
    let safetyScore = 100;
    if (isExplicit) safetyScore -= 50;
    if (isAdult) safetyScore -= 40;
    if (isViolent) safetyScore -= 30;
    if (isWeapon) safetyScore -= 25;
    if (isDrug) safetyScore -= 20;
    if (isSpoof) safetyScore -= 15;
    if (isHate) safetyScore -= 35;
    
    // Store analysis results
    const db = admin.firestore();
    await db.collection('content_analysis').add({
      contentId: contentId,
      userId: userId,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      text: text,
      analysis: {
        isExplicit: isExplicit,
        isAdult: isAdult,
        isViolent: isViolent,
        isRacy: isRacy,
        isWeapon: isWeapon,
        isDrug: isDrug,
        isMedical: isMedical,
        isSpoof: isSpoof,
        isHate: isHate,
        safetyScore: safetyScore,
        confidence: analysis.explicitAnnotation?.split(' ')[1] || '0.0',
        labels: labels,
        detectedObjects: detectedObjects,
        detectedText: detectedText,
        detectedFaces: detectedFaces,
        detectedLogos: detectedLogos,
        detectedWebEntities: detectedWebEntities,
        detectedUrls: detectedUrls,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // If content is flagged, automatically flag it
    if (shouldFlag) {
      await flagInappropriateContent(contentId, userId, {
        reason: _getFlagReason(isExplicit, isAdult, isViolent, isWeapon, isDrug, isSpoof, isHate),
        description: _getFlagDescription(isExplicit, isAdult, isViolent, isWeapon, isDrug, isSpoof, isHate),
        analysisData: {
          safetyScore: safetyScore,
          labels: labels,
          detectedObjects: detectedObjects,
          detectedText: detectedText,
          detectedFaces: detectedFaces,
          detectedLogos: detectedLogos,
          detectedWebEntities: detectedWebEntities,
          detectedUrls: detectedUrls,
        },
      });
    }
    
    return {
      success: true,
      message: 'Content analyzed successfully',
      contentId: contentId,
      isFlagged: shouldFlag,
      safetyScore: safetyScore,
      analysis: {
        isExplicit: isExplicit,
        isAdult: isAdult,
        isViolent: isViolent,
        isRacy: isRacy,
        isWeapon: isWeapon,
        isDrug: isDrug,
        isMedical: isMedical,
        isSpoof: isSpoof,
        isHate: isHate,
        safetyScore: safetyScore,
        labels: labels,
        detectedObjects: detectedObjects,
        detectedText: detectedText,
        detectedFaces: detectedFaces,
        detectedLogos: detectedLogos,
        detectedWebEntities: detectedWebEntities,
        detectedUrls: detectedUrls,
      },
    };
  } catch (error) {
    console.error(`Content analysis error: ${error}`);
    throw new functions.https.HttpsError('analysis-error', error.message);
  }
});

// Flag inappropriate content
exports.flagInappropriateContent = functions.https.onCall(async (data, context) => {
  const { contentId, userId, reason, description, analysisData } = data;
  
  console.log(`Flagging content: ${contentId}`);
  
  try {
    // Validate input
    if (!contentId || !userId || !reason) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    
    const db = admin.firestore();
    
    // Add to flagged content collection
    await db.collection('flagged_content').add({
      contentId: contentId,
      userId: userId,
      reason: reason,
      description: description,
      analysisData: analysisData,
      flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'pending_review',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Add to moderation queue
    await db.collection('moderation_queue').add({
      contentId: contentId,
      userId: userId,
      action: 'flag_content',
      reason: reason,
      description: description,
      analysisData: analysisData,
      queuedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'queued',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Update content status
    await db.collection('content').doc(contentId).update({
      moderationStatus: 'flagged',
      flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Log moderation action
    await db.collection('moderation_reports').add({
      contentId: contentId,
      userId: userId,
      action: 'content_flagged',
      reason: reason,
      description: description,
      analysisData: analysisData,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    return {
      success: true,
      message: 'Content flagged successfully',
      contentId: contentId,
      reason: reason,
    };
  } catch (error) {
    console.error(`Flagging error: ${error}`);
    throw new functions.https.HttpsError('flagging-error', error.message);
  }
});

// Process moderation queue
exports.processModerationQueue = functions.pubsub.schedule('*/5 * * *') // Every 5 minutes
  .onRun(async (context) => {
    console.log('Processing moderation queue...');
    
    try {
      const db = admin.firestore();
      const snapshot = await db.collection('moderation_queue')
        .where('status', '==', 'queued')
        .orderBy('queuedAt', ascending: true)
        .limit(20)
        .get();
      
      if (snapshot.empty) {
        console.log('No items in moderation queue');
        return {
          success: true,
          message: 'No items to process',
          processedCount: 0,
        };
      }
      
      let processedCount = 0;
      const batch = db.batch();
      
      for (const doc of snapshot.docs) {
        const data = doc.data();
        const contentId = data.contentId;
        const action = data.action;
        
        switch (action) {
          case 'flag_content':
            // Content already flagged in the flag function
            break;
            
          case 'delete_content':
            await deleteContent(contentId, data.userId);
            processedCount++;
            break;
            
          case 'approve_content':
            await approveContent(contentId, data.userId);
            processedCount++;
            break;
            
          case 'reject_content':
            await rejectContent(contentId, data.userId, data.reason, data.reviewNotes);
            processedCount++;
            break;
        }
        
        // Update queue item status
        await doc.ref.update({
          status: 'processed',
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        // Remove from queue
        await doc.ref.delete();
      }
      
      await batch.commit();
      
      console.log(`Processed ${processedCount} items from moderation queue`);
      
      return {
        success: true,
        message: 'Moderation queue processed successfully',
        processedCount: processedCount,
      };
    } catch (error) {
      console.error(`Queue processing error: ${error}`);
      return {
        success: false,
        message: error.message,
        processedCount: 0,
      };
    }
  }
});

// Delete content
exports.deleteContent = functions.https.onCall(async (data, context) => {
  const { contentId, userId } = data;
  
  console.log(`Deleting content: ${contentId}`);
  
  try {
    if (!contentId || !userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    
    const db = admin.firestore();
    
    // Get content details
    const contentDoc = await db.collection('content').doc(contentId).get();
    if (!contentDoc.exists) {
      throw new functions.https.HttpsError('content-not-found', 'Content not found');
    }
    
    const contentData = contentDoc.data();
    
    // Delete from flagged content
    await db.collection('flagged_content').doc(contentId).delete();
    
    // Remove from moderation queue
    await db.collection('moderation_queue')
      .where('contentId', '==', contentId)
      .get()
      .then((querySnapshot) => {
        for (const doc of querySnapshot.docs) {
          await doc.reference.delete();
        }
      });
    
    // Delete content document
    await db.collection('content').doc(contentId).delete();
    
    // Delete associated media files from Storage
    const storage = new Storage();
    if (contentData.imageUrl) {
      try {
        const fileRef = storage.bucket('djinan-content').file(contentData.imageUrl);
        await fileRef.delete();
      } catch (error) {
        console.error(`Failed to delete image: ${error}`);
      }
    }
    
    if (contentData.videoUrl) {
      try {
        const fileRef = storage.bucket('djinan-content').file(contentData.videoUrl);
        await fileRef.delete();
      } catch (error) {
        console.error(`Failed to delete video: ${error}`);
      }
    }
    
    // Log deletion
    await db.collection('moderation_reports').add({
      contentId: contentId,
      userId: userId,
      action: 'content_deleted',
      reason: 'moderator_action',
      description: 'Content deleted by moderator',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    return {
      success: true,
      message: 'Content deleted successfully',
      contentId: contentId,
    };
  } catch (error) {
    console.error(`Deletion error: ${error}`);
    throw new functions.https.HttpsError('deletion-error', error.message);
  }
});

// Approve content
exports.approveContent = functions.https.onCall(async (data, context) => {
  const { contentId, userId } = data;
  
  console.log(`Approving content: ${contentId}`);
  
  try {
    if (!contentId || !userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    
    const db = admin.firestore();
    
    // Update content status to approved
    await db.collection('content').doc(contentId).update({
      moderationStatus: 'approved',
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      approvedBy: userId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Remove from moderation queue
    await db.collection('moderation_queue')
      .where('contentId', '==', contentId)
      .get()
      .then((querySnapshot) => {
        for (const doc of querySnapshot.docs) {
          await doc.reference.delete();
        }
      });
    
    // Log approval
    await db.collection('moderation_reports').add({
      contentId: contentId,
      userId: userId,
      action: 'content_approved',
      reason: 'moderator_action',
      description: 'Content approved by moderator',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    return {
      success: true,
      message: 'Content approved successfully',
      contentId: contentId,
    };
  } catch (error) {
    console.error(`Approval error: ${error}`);
    throw new functions.https.HttpsError('approval-error', error.message);
  }
});

// Reject content
exports.rejectContent = functions.https.onCall(async (data, context) => {
  const { contentId, userId, reason, reviewNotes } = data;
  
  console.log(`Rejecting content: ${contentId}`);
  
  try {
    if (!contentId || !userId || !reason) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    
    const db = admin.firestore();
    
    // Update content status to rejected
    await db.collection('content').doc(contentId).update({
      moderationStatus: 'rejected',
      rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      rejectedBy: userId,
      rejectionReason: reason,
      reviewNotes: reviewNotes,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Remove from moderation queue
    await db.collection('moderation_queue')
      .where('contentId', '==', contentId)
      .get()
      .then((querySnapshot) => {
        for (const doc of querySnapshot.docs) {
          await doc.reference.delete();
        }
      });
    
    // Log rejection
    await db.collection('moderation_reports').add({
      contentId: contentId,
      userId: userId,
      action: 'content_rejected',
      reason: reason,
      reviewNotes: reviewNotes,
      description: 'Content rejected by moderator',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    return {
      success: true,
      message: 'Content rejected successfully',
      contentId: contentId,
      reason: reason,
    };
  } catch (error) {
    console.error(`Rejection error: ${error}`);
    throw new functions.https.HttpsError('rejection-error', error.message);
  }
});

// Get moderation statistics
exports.getModerationStats = functions.https.onCall(async (data, context) => {
  const { userId, period = '30_days' } = data;
  
  console.log(`Getting moderation stats for user: ${userId}`);
  
  try {
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing user ID');
    }
    
    const db = admin.firestore();
    const now = new Date();
    let startDate;
    
    // Calculate start date based on period
    if (period === '7_days') {
      startDate = new Date(now.getTime() - (7 * 24 * 60 * 60 * 1000));
    } else if (period === '30_days') {
      startDate = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));
    } else {
      startDate = new Date(now.getTime() - (90 * 24 * 60 * 60 * 1000));
    }
    
    // Get flagged content stats
    const flaggedSnapshot = await db.collection('flagged_content')
      .where('flaggedAt', '>=', startDate)
      .get();
    
    // Get moderation queue stats
    const queueSnapshot = await db.collection('moderation_queue')
      .where('queuedAt', '>=', startDate)
      .get();
    
    // Get reports stats
    const reportsSnapshot = await db.collection('moderation_reports')
      .where('createdAt', '>=', startDate)
      .get();
    
    // Calculate statistics
    const totalFlagged = flaggedSnapshot.size;
    const queueSize = queueSnapshot.size;
    const totalReports = reportsSnapshot.size;
    const autoFlagged = flaggedSnapshot.docs
      .filter(doc => doc.data().reason === 'auto_flagged')
      .length;
    const manuallyFlagged = flaggedSnapshot.docs
      .filter(doc => doc.data().reason !== 'auto_flagged')
      .length;
    const processedToday = queueSnapshot.docs
      .filter(doc => {
        const queuedDate = doc.data().queuedAt.toDate();
        return queuedDate.toDateString() === now.toDateString();
      })
      .filter(doc => doc.data().status === 'processed')
      .length;
    
    return {
      success: true,
      period: period,
      stats: {
        totalFlagged: totalFlagged,
        queueSize: queueSize,
        totalReports: totalReports,
        autoFlagged: autoFlagged,
        manuallyFlagged: manuallyFlagged,
        processedToday: processedToday,
      },
    };
  } catch (error) {
    console.error(`Stats error: ${error}`);
    throw new functions.https.HttpsError('stats-error', error.message);
  }
});

// Helper functions
function _getObjectType(name) {
  const lowerName = name.toLowerCase();
  
  if (lowerName.includes('weapon') || lowerName.includes('gun') || lowerName.includes('knife')) {
    return 'weapon';
  } else if (lowerName.includes('person') || lowerName.includes('human')) {
    return 'person';
  } else if (lowerName.includes('car') || lowerName.includes('vehicle')) {
    return 'vehicle';
  } else if (lowerName.includes('animal') || lowerName.includes('dog') || lowerName.includes('cat')) {
    return 'animal';
  } else if (lowerName.includes('food') || lowerName.includes('drink')) {
    return 'food';
  } else {
    return 'general';
  }
}

function _getFlagReason(isExplicit, isAdult, isViolent, isWeapon, isDrug, isSpoof, isHate) {
  if (isExplicit) return 'explicit_content';
  if (isAdult) return 'adult_content';
  if (isViolent) return 'violence';
  if (isWeapon) return 'weapon';
  if (isDrug) return 'drug';
  if (isSpoof) return 'spoof';
  if (isHate) return 'hate_speech';
  return 'inappropriate';
}

function _getFlagDescription(isExplicit, isAdult, isViolent, isWeapon, isDrug, isSpoof, isHate) {
  const reasons = [];
  
  if (isExplicit) reasons.push('explicit content');
  if (isAdult) reasons.push('adult content');
  if (isViolent) reasons.push('violent content');
  if (isWeapon) reasons.push('weapon detection');
  if (isDrug) reasons.push('drug detection');
  if (isSpoof) reasons.push('spoof content');
  if (isHate) reasons.push('hate speech');
  
  return reasons.join(', ');
}
