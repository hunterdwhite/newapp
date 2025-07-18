const admin = require("firebase-admin");
const axios = require("axios");
require("dotenv").config();

admin.initializeApp();
const db = admin.firestore();

const DISCOGS_TOKEN = process.env.DISCOGS_TOKEN;
const DISC_USERNAME = process.env.DISCOGS_USERNAME;
const REQUEST_DELAY_MS = 1100;


/**
 * Fetches the user's full Discogs collection from folder 0 (All).
 * @return {Promise<Array>} List of collected releases.
 */
async function getDiscogsCollection() {
  const url =
    `https://api.discogs.com/users/${DISC_USERNAME}/collection/folders/0/releases` +
    `?token=${DISCOGS_TOKEN}&per_page=100&page=1`;
  const res = await axios.get(url);
  return res.data.releases;
}

/**
 * Fetches detailed release data from Discogs for a given release ID.
 * @param {string|number} releaseId - Discogs release ID.
 * @return {Promise<Object>} Release metadata.
 */
async function fetchReleaseData(releaseId) {
  const url =
    `https://api.discogs.com/releases/${releaseId}?token=${DISCOGS_TOKEN}`;
  const res = await axios.get(url);
  return res.data;
}

/**
 * Delays execution for a given number of milliseconds.
 * Useful for throttling API requests to avoid rate limits.
 *
 * @param {number} ms - The number of milliseconds to wait.
 * @return {Promise<void>} A promise that resolves after the delay.
 */
function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}


/**
 * Syncs the Discogs collection into Firestore, updating or inserting
 * album documents, and maintaining inventory availability.
 */
async function syncAlbums() {
  const collection = await getDiscogsCollection();

  for (const item of collection) {
    const releaseId = item.basic_information.id;
    const release = await fetchReleaseData(releaseId);
    await delay(REQUEST_DELAY_MS);

    const albumName = release.title;
    const artist = release.artists_sort;
    const matchingQuery = db
        .collection("albums")
        .where("albumName", "==", albumName)
        .where("artist", "==", artist);

    const snapshot = await matchingQuery.get();

    let albumDocRef;

    const albumData = {
      albumName,
      artist,
      coverUrl:
        release.images && release.images.length > 0 ?
          release.images[0].uri :
          "",
      discogsId: release.id,
      genres: release.genres,
      styles: release.styles,
      releaseYear: release.released ?
        release.released.split("-")[0] :
        "",
      label:
        release.labels && release.labels.length > 0 ?
          release.labels[0].name :
          "",
      country: release.country,
      updatedAt: new Date(),
    };

    if (!snapshot.empty) {
      const doc = snapshot.docs[0];
      // Exclude coverUrl from update if album exists
      const albumDataWithoutCover = (({coverUrl, ...rest}) => rest)(albumData);
      await doc.ref.set(albumDataWithoutCover, {merge: true});
      albumDocRef = doc.ref;
    } else {
      const docRef = await db.collection("albums").add({
        ...albumData,
        createdAt: new Date(),
      });
      albumDocRef = docRef;
    }

    // Upsert inventory doc for this release
    const inventoryRef = db.collection("inventory").doc(release.id.toString());

    const invSnapshot = await inventoryRef.get();

    if (invSnapshot.exists) {
      // Increment quantity if already exists
      await inventoryRef.update({
        quantity: admin.firestore.FieldValue.increment(1),
        lastUpdated: new Date(),
      });
    } else {
      // Create new inventory entry
      await inventoryRef.set({
        discogsId: release.id,
        albumId: albumDocRef.id,
        albumName,
        artist,
        coverUrl: albumData.coverUrl,
        releaseYear: albumData.releaseYear,
        genres: albumData.genres,
        quantity: 1,
        lastUpdated: new Date(),
      });
    }

    console.log(`Synced and inventoried: ${albumName} - ${artist}`);
  }
}


/**
 * Firebase Cloud Function: runs every 24 hours to sync Discogs data.
 */
const {onSchedule} = require("firebase-functions/v2/scheduler");

exports.nightlyDiscogsSync = onSchedule("every 24 hours", async () => {
  console.log("Starting Discogs sync job...");
  await syncAlbums();
  console.log("Discogs sync complete.");
});
