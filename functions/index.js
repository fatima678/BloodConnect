const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

const REGION = "asia-south1";
const CHANNEL_ID = "blood_requests_channel";
const DEBUG_COLLECTION = "push_debug_logs";

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

    if (value === null || value === undefined) {
      continue;
    }

    const text = String(value).trim();

    if (text && text.toLowerCase() !== "null") {
      return text;
    }
  }

  return "";
}

function normalizeRole(role, fallbackRole = "patient") {
  const value = String(role || "").trim().toLowerCase();

  if (value === "volunteer") {
    return "team_volunteer";
  }

  if (value === "team_volunteer") {
    return "team_volunteer";
  }

  if (value === "patient" || value === "donor" || value === "admin") {
    return value;
  }

  return fallbackRole;
}

function roleCollection(role) {
  const cleanRole = normalizeRole(role);

  return ROLE_COLLECTIONS[cleanRole] || null;
}

function resolveRecipientUid(notification, role) {
  const cleanRole = normalizeRole(role);

  if (cleanRole === "donor") {
    return readString(notification, [
      "recipient_uid",
      "receiver_uid",
      "user_uid",
      "donor_uid",
      "donor_user_id",
      "donor_id",
    ]);
  }

  if (cleanRole === "patient") {
    return readString(notification, [
      "recipient_uid",
      "receiver_uid",
      "user_uid",
      "patient_uid",
      "patient_id",
      "patient_user_id",
    ]);
  }

  if (cleanRole === "team_volunteer") {
    return readString(notification, [
      "recipient_uid",
      "receiver_uid",
      "user_uid",
      "volunteer_uid",
      "team_volunteer_uid",
    ]);
  }

  if (cleanRole === "admin") {
    return readString(notification, [
      "recipient_uid",
      "receiver_uid",
      "user_uid",
      "admin_uid",
    ]);
  }

  return readString(notification, [
    "recipient_uid",
    "receiver_uid",
    "user_uid",
  ]);
}

function safeDataValue(value) {
  if (value === null || value === undefined) {
    return "";
  }

  return String(value);
}

function buildDataPayload(data) {
  const payload = {};

  for (const [key, value] of Object.entries(data)) {
    payload[key] = safeDataValue(value);
  }

  return payload;
}

async function writeDebug({
  notificationId,
  collectionName,
  stage,
  role = "",
  recipientUid = "",
  userPath = "",
  tokenCount = 0,
  successCount = null,
  failureCount = null,
  error = "",
  extra = {},
}) {
  const debugData = {
    notification_id: notificationId,
    collection_name: collectionName,
    stage,
    role,
    recipient_uid: recipientUid,
    user_path: userPath,
    token_count: tokenCount,
    success_count: successCount,
    failure_count: failureCount,
    error,
    extra,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  logger.info("PUSH DEBUG", debugData);

  await db.collection(DEBUG_COLLECTION).add(debugData);
}

async function markNotification(snap, data) {
  await snap.ref.set(
    {
      ...data,
      push_checked_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

async function getRecipientUserData({ uid, role }) {
  const collectionName = roleCollection(role);

  if (!uid || !collectionName) {
    return null;
  }

  const roleUserRef = db
    .collection("users")
    .doc("roles")
    .collection(collectionName)
    .doc(uid);

  const roleUserSnap = await roleUserRef.get();

  if (roleUserSnap.exists) {
    return {
      ref: roleUserRef,
      data: roleUserSnap.data() || {},
      path: roleUserRef.path,
    };
  }

  const directUserRef = db.collection("users").doc(uid);
  const directUserSnap = await directUserRef.get();

  if (directUserSnap.exists) {
    return {
      ref: directUserRef,
      data: directUserSnap.data() || {},
      path: directUserRef.path,
    };
  }

  return null;
}

function collectFcmTokens(userData) {
  const tokens = new Set();

  const directToken = readString(userData, [
    "fcm_token",
    "fcmToken",
    "device_token",
    "deviceToken",
    "notification_token",
    "notificationToken",
    "messaging_token",
    "messagingToken",
  ]);

  if (directToken) {
    tokens.add(directToken);
  }

  const possibleArrays = [
    userData.fcm_tokens,
    userData.fcmTokens,
    userData.device_tokens,
    userData.deviceTokens,
    userData.notification_tokens,
    userData.notificationTokens,
    userData.messaging_tokens,
    userData.messagingTokens,
    userData.tokens,
  ];

  for (const item of possibleArrays) {
    if (!Array.isArray(item)) {
      continue;
    }

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
    userData.device_map,
    userData.deviceMap,
  ];

  for (const deviceMap of possibleDeviceMaps) {
    if (
      !deviceMap ||
      typeof deviceMap !== "object" ||
      Array.isArray(deviceMap)
    ) {
      continue;
    }

    for (const device of Object.values(deviceMap)) {
      if (typeof device === "string" && device.trim()) {
        tokens.add(device.trim());
        continue;
      }

      if (!device || typeof device !== "object") {
        continue;
      }

      const token = readString(device, [
        "fcm_token",
        "fcmToken",
        "token",
        "device_token",
        "deviceToken",
        "notification_token",
        "notificationToken",
      ]);

      if (token) {
        tokens.add(token);
      }
    }
  }

  return Array.from(tokens);
}

function buildNotificationPayload({
  snap,
  notification,
  fallbackRole,
  collectionName,
}) {
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

  const roleFromDocument = readString(notification, [
    "role",
    "recipient_role",
    "receiver_role",
    "user_role",
  ]);

  const role = normalizeRole(roleFromDocument, fallbackRole);

  const recipientUid = resolveRecipientUid(notification, role);

  return {
    title,
    body,
    type,
    role,
    recipientUid,
    data: buildDataPayload({
      notification_id: snap.id,
      collection: collectionName,
      type,
      role,
      recipient_uid: recipientUid,

      request_id: readString(notification, [
        "request_id",
        "donation_request_id",
        "blood_request_id",
      ]),

      donation_request_id: readString(notification, [
        "donation_request_id",
        "request_id",
      ]),

      blood_request_id: readString(notification, [
        "blood_request_id",
      ]),

      donor_request_id: readString(notification, [
        "donor_request_id",
      ]),

      donor_uid: readString(notification, [
        "donor_uid",
        "donor_user_id",
        "donor_id",
      ]),

      patient_uid: readString(notification, [
        "patient_uid",
        "patient_id",
        "patient_user_id",
      ]),

      volunteer_uid: readString(notification, [
        "volunteer_uid",
        "team_volunteer_uid",
      ]),

      status: readString(notification, [
        "status",
        "request_status",
      ]),
    }),
  };
}

async function clearInvalidSingleToken({
  recipient,
  invalidTokens,
}) {
  if (!recipient || !recipient.ref || invalidTokens.length === 0) {
    return;
  }

  const currentToken = readString(recipient.data, [
    "fcm_token",
    "fcmToken",
    "device_token",
    "deviceToken",
  ]);

  if (!currentToken || !invalidTokens.includes(currentToken)) {
    return;
  }

  await recipient.ref.set(
    {
      fcm_token: admin.firestore.FieldValue.delete(),
      fcmToken: admin.firestore.FieldValue.delete(),
      device_token: admin.firestore.FieldValue.delete(),
      deviceToken: admin.firestore.FieldValue.delete(),
      fcm_token_updated_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

async function handleNotificationCreate(event, fallbackRole, collectionName) {
  const snap = event.data;

  if (!snap) {
    logger.warn("No snapshot found in event.", {
      collectionName,
      fallbackRole,
    });

    return;
  }

  const notification = snap.data() || {};
  const notificationId = snap.id;

  await writeDebug({
    notificationId,
    collectionName,
    stage: "trigger_started",
    extra: {
      fallbackRole,
    },
  });

  if (notification.push_sent === true) {
    await writeDebug({
      notificationId,
      collectionName,
      stage: "already_push_sent_skipped",
    });

    return;
  }

  const payload = buildNotificationPayload({
    snap,
    notification,
    fallbackRole,
    collectionName,
  });

  await markNotification(snap, {
    push_debug_stage: "payload_built",
    push_role: payload.role,
    push_recipient_uid: payload.recipientUid || null,
  });

  await writeDebug({
    notificationId,
    collectionName,
    stage: "payload_built",
    role: payload.role,
    recipientUid: payload.recipientUid,
    extra: {
      title: payload.title,
      body: payload.body,
      type: payload.type,
    },
  });

  if (!payload.recipientUid) {
    await markNotification(snap, {
      push_sent: false,
      push_error: "recipient_uid_missing",
      push_debug_stage: "recipient_uid_missing",
    });

    await writeDebug({
      notificationId,
      collectionName,
      stage: "recipient_uid_missing",
      role: payload.role,
      error: "recipient_uid_missing",
    });

    return;
  }

  const recipient = await getRecipientUserData({
    uid: payload.recipientUid,
    role: payload.role,
  });

  if (!recipient) {
    await markNotification(snap, {
      push_sent: false,
      push_error: "recipient_user_not_found",
      push_debug_stage: "recipient_user_not_found",
      push_role: payload.role,
      push_recipient_uid: payload.recipientUid,
    });

    await writeDebug({
      notificationId,
      collectionName,
      stage: "recipient_user_not_found",
      role: payload.role,
      recipientUid: payload.recipientUid,
      error: "recipient_user_not_found",
    });

    return;
  }

  await writeDebug({
    notificationId,
    collectionName,
    stage: "recipient_user_found",
    role: payload.role,
    recipientUid: payload.recipientUid,
    userPath: recipient.path,
  });

  const tokens = collectFcmTokens(recipient.data);

  await markNotification(snap, {
    push_debug_stage: "tokens_checked",
    push_user_path: recipient.path,
    push_token_count: tokens.length,
  });

  if (tokens.length === 0) {
    await markNotification(snap, {
      push_sent: false,
      push_error: "fcm_token_not_found",
      push_debug_stage: "fcm_token_not_found",
      push_role: payload.role,
      push_recipient_uid: payload.recipientUid,
      push_user_path: recipient.path,
      push_token_count: 0,
    });

    await writeDebug({
      notificationId,
      collectionName,
      stage: "fcm_token_not_found",
      role: payload.role,
      recipientUid: payload.recipientUid,
      userPath: recipient.path,
      tokenCount: 0,
      error: "fcm_token_not_found",
      extra: {
        availableUserFields: Object.keys(recipient.data || {}),
      },
    });

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
        channelId: CHANNEL_ID,
        sound: "default",
        priority: "high",
        defaultSound: true,
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

  await writeDebug({
    notificationId,
    collectionName,
    stage: "sending_to_fcm",
    role: payload.role,
    recipientUid: payload.recipientUid,
    userPath: recipient.path,
    tokenCount: tokens.length,
  });

  await markNotification(snap, {
    push_debug_stage: "sending_to_fcm",
    push_token_count: tokens.length,
  });

  let response;

  try {
    response = await admin.messaging().sendEachForMulticast(message);
  } catch (error) {
    await markNotification(snap, {
      push_sent: false,
      push_error: "fcm_send_exception",
      push_error_message: error.message,
      push_debug_stage: "fcm_send_exception",
      push_role: payload.role,
      push_recipient_uid: payload.recipientUid,
      push_user_path: recipient.path,
    });

    await writeDebug({
      notificationId,
      collectionName,
      stage: "fcm_send_exception",
      role: payload.role,
      recipientUid: payload.recipientUid,
      userPath: recipient.path,
      tokenCount: tokens.length,
      error: error.message,
    });

    return;
  }

  const failedTokens = [];
  const invalidTokens = [];

  response.responses.forEach((result, index) => {
    if (result.success) {
      return;
    }

    const token = tokens[index];
    const code = result.error && result.error.code;
    const errorMessage = result.error && result.error.message;

    failedTokens.push({
      token,
      code,
      message: errorMessage,
    });

    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      invalidTokens.push(token);
    }
  });

  await markNotification(snap, {
    push_sent: response.successCount > 0,
    push_success_count: response.successCount,
    push_failure_count: response.failureCount,
    push_failed_tokens_count: failedTokens.length,
    push_error: response.successCount > 0 ? null : "fcm_send_failed",
    push_debug_stage: "fcm_response_received",
    push_role: payload.role,
    push_recipient_uid: payload.recipientUid,
    push_user_path: recipient.path,
    push_token_count: tokens.length,
    push_failed_tokens: failedTokens,
  });

  await writeDebug({
    notificationId,
    collectionName,
    stage: "fcm_response_received",
    role: payload.role,
    recipientUid: payload.recipientUid,
    userPath: recipient.path,
    tokenCount: tokens.length,
    successCount: response.successCount,
    failureCount: response.failureCount,
    error: response.successCount > 0 ? "" : "fcm_send_failed",
    extra: {
      failedTokens,
    },
  });

  await clearInvalidSingleToken({
    recipient,
    invalidTokens,
  });
}

/*
 * Patient notifications
 * Donor accept/reject ke baad patient ko push.
 */
exports.sendPushOnPatientNotificationCreate = onDocumentCreated(
  {
    document: "notifications/{notificationId}",
    region: REGION,
  },
  async (event) => {
    await handleNotificationCreate(
      event,
      "patient",
      "notifications"
    );
  }
);

/*
 * Donor notifications
 * Patient donor ko request send kare to donor ko push.
 */
exports.sendPushOnDonorNotificationCreate = onDocumentCreated(
  {
    document: "donor_notifications/{notificationId}",
    region: REGION,
  },
  async (event) => {
    await handleNotificationCreate(
      event,
      "donor",
      "donor_notifications"
    );
  }
);

/*
 * Volunteer notifications
 */
exports.sendPushOnVolunteerNotificationCreate = onDocumentCreated(
  {
    document: "volunteer_notifications/{notificationId}",
    region: REGION,
  },
  async (event) => {
    await handleNotificationCreate(
      event,
      "team_volunteer",
      "volunteer_notifications"
    );
  }
);

/*
 * Admin notifications
 */
exports.sendPushOnAdminNotificationCreate = onDocumentCreated(
  {
    document: "admin_notifications/{notificationId}",
    region: REGION,
  },
  async (event) => {
    await handleNotificationCreate(
      event,
      "admin",
      "admin_notifications"
    );
  }
);