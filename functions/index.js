const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

const ROLE_COLLECTIONS = {
  patient: "patients",
  donor: "donors",
  team_volunteer: "team_volunteers",
  volunteer: "team_volunteers",
  admin: "admins",
};

function readString(data, keys) {
  for (const key of keys) {
    const value = data[key];

    if (value === null || value === undefined) continue;

    const text = String(value).trim();

    if (text && text.toLowerCase() !== "null") {
      return text;
    }
  }

  return "";
}

function normalizeRole(role) {
  const value = String(role || "").trim().toLowerCase();

  if (value === "volunteer") {
    return "team_volunteer";
  }

  return value || "patient";
}

function roleCollection(role) {
  const cleanRole = normalizeRole(role);

  return ROLE_COLLECTIONS[cleanRole] || null;
}

async function getRecipientUserData({ uid, role }) {
  const collectionName = roleCollection(role);

  if (!collectionName) {
    logger.warn("Invalid role collection.", { uid, role });
    return null;
  }

  const userRef = db
    .collection("users")
    .doc("roles")
    .collection(collectionName)
    .doc(uid);

  const userSnap = await userRef.get();

  if (!userSnap.exists) {
    logger.warn("Recipient user document not found.", {
      uid,
      role,
      path: userRef.path,
    });

    return null;
  }

  return {
    ref: userRef,
    data: userSnap.data() || {},
  };
}

function collectFcmTokens(userData) {
  const tokens = new Set();

  const directToken = readString(userData, [
    "fcm_token",
    "fcmToken",
    "device_token",
    "deviceToken",
  ]);

  if (directToken) {
    tokens.add(directToken);
  }

  const possibleArrays = [
    userData.fcm_tokens,
    userData.fcmTokens,
    userData.device_tokens,
    userData.deviceTokens,
    userData.tokens,
  ];

  for (const item of possibleArrays) {
    if (!Array.isArray(item)) continue;

    for (const token of item) {
      if (typeof token === "string" && token.trim()) {
        tokens.add(token.trim());
      }
    }
  }

  const possibleDeviceMaps = [
    userData.devices,
    userData.fcm_devices,
    userData.fcmDevices,
  ];

  for (const deviceMap of possibleDeviceMaps) {
    if (!deviceMap || typeof deviceMap !== "object" || Array.isArray(deviceMap)) {
      continue;
    }

    for (const device of Object.values(deviceMap)) {
      if (typeof device === "string" && device.trim()) {
        tokens.add(device.trim());
        continue;
      }

      if (!device || typeof device !== "object") continue;

      const token = readString(device, [
        "fcm_token",
        "fcmToken",
        "token",
        "device_token",
        "deviceToken",
      ]);

      if (token) {
        tokens.add(token);
      }
    }
  }

  return Array.from(tokens);
}

function buildNotificationPayload({ snap, notification }) {
  const title =
    readString(notification, [
      "title",
      "notification_title",
    ]) || "Blood Connect";

  const body =
    readString(notification, [
      "body",
      "message",
      "notification_body",
    ]) || "You have a new notification.";

  const type =
    readString(notification, [
      "type",
      "notification_type",
    ]) || "notification";

  const role = normalizeRole(
    readString(notification, [
      "role",
      "recipient_role",
      "receiver_role",
      "user_role",
    ])
  );

  const recipientUid = readString(notification, [
    "recipient_uid",
    "receiver_uid",
    "user_uid",
    "patient_uid",
    "donor_uid",
    "volunteer_uid",
    "admin_uid",
  ]);

  return {
    title,
    body,
    type,
    role,
    recipientUid,
    data: {
      notification_id: snap.id,
      type,
      role,
      recipient_uid: recipientUid,
    },
  };
}

exports.sendPushOnNotificationCreate = onDocumentCreated(
  {
    document: "notifications/{notificationId}",
    region: "asia-south1",
  },
  async (event) => {
    const snap = event.data;

    if (!snap) {
      logger.warn("No snapshot found in event.");
      return;
    }

    const notification = snap.data() || {};

    /*
      Avoid accidental re-send if later you copy this code to an update trigger.
    */
    if (notification.push_sent === true) {
      logger.info("Push already sent. Skipping.", {
        notificationId: snap.id,
      });
      return;
    }

    const payload = buildNotificationPayload({
      snap,
      notification,
    });

    if (!payload.recipientUid) {
      logger.warn("Notification recipient uid missing.", {
        notificationId: snap.id,
        notification,
      });

      await snap.ref.set(
        {
          push_sent: false,
          push_error: "recipient_uid_missing",
          push_checked_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return;
    }

    const recipient = await getRecipientUserData({
      uid: payload.recipientUid,
      role: payload.role,
    });

    if (!recipient) {
      await snap.ref.set(
        {
          push_sent: false,
          push_error: "recipient_user_not_found",
          push_checked_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return;
    }

    const tokens = collectFcmTokens(recipient.data);

    if (tokens.length === 0) {
      logger.warn("No FCM token found for recipient.", {
        notificationId: snap.id,
        uid: payload.recipientUid,
        role: payload.role,
      });

      await snap.ref.set(
        {
          push_sent: false,
          push_error: "fcm_token_not_found",
          push_checked_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return;
    }

    const message = {
      tokens,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data,
      android: {
        priority: "high",
        notification: {
          channelId: "blood_requests_channel",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    logger.info("FCM push send result.", {
      notificationId: snap.id,
      uid: payload.recipientUid,
      role: payload.role,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });

    const failedTokens = [];
    const invalidTokens = [];

    response.responses.forEach((result, index) => {
      if (result.success) return;

      const token = tokens[index];
      const code = result.error && result.error.code;
      const message = result.error && result.error.message;

      failedTokens.push({
        token,
        code,
        message,
      });

      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        invalidTokens.push(token);
      }
    });

    await snap.ref.set(
      {
        push_sent: response.successCount > 0,
        push_success_count: response.successCount,
        push_failure_count: response.failureCount,
        push_failed_tokens_count: failedTokens.length,
        push_error: response.successCount > 0 ? null : "fcm_send_failed",
        push_checked_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    /*
      Your app currently stores one token in fcm_token.
      If that token is invalid, clear it so next login/token refresh can save new one.
    */
    if (invalidTokens.length > 0) {
      const currentToken = readString(recipient.data, ["fcm_token"]);

      if (currentToken && invalidTokens.includes(currentToken)) {
        await recipient.ref.set(
          {
            fcm_token: admin.firestore.FieldValue.delete(),
            fcm_token_updated_at: admin.firestore.FieldValue.serverTimestamp(),
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
    }
  }
);