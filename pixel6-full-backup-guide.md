# Google Pixel 6 Full Backup Guide (Including App Data)

## Important Reality Check

There is **no single tool** on a stock, unrooted Pixel 6 that backs up **100% of app data**. Android allows app developers to opt out of the standard backup APIs, and many sensitive apps (WhatsApp, Signal, banking apps, password managers, some games) do exactly that.

This guide gives you two paths:

- **Path 1:** Unrooted, stock Android. Easiest, covers ~90% of data.
- **Path 2:** True full image backup. Requires unlocking the bootloader (which wipes the phone), installing a custom recovery, and making a NANDroid backup.

If you want a true forensic copy of **everything**, you need Path 2. If you just want a robust, restorable backup, Path 1 is usually enough.

---

## Path 1: Unrooted, Stock Android

### Step 1: Google One Cloud Backup

This is your baseline. It backs up:

- Apps and app data (for apps that allow it)
- Contacts, SMS, call history
- Device settings, Wi-Fi passwords
- Photos and videos (if using Google Photos)

#### Actions

1. Open **Settings → Google → Backup**
2. Turn on **Back up by Google One**
3. Tap **Back up now** and wait for it to finish

#### Verify

- Open the **Google One** app → **Device backup**
- Check that the timestamp is recent
- Ensure **App data** shows a substantial size (not 0 bytes)
- Or check online at [one.google.com/storage](https://one.google.com/storage)

---

### Step 2: Back Up Photos and Videos Separately

Google Photos backup may or may not be included depending on your settings. Back it up explicitly.

#### Actions

1. Open **Google Photos**
2. Tap your profile picture → **Photos settings → Back up**
3. Choose **Backup quality**: Original quality or Storage Saver
4. Wait for all items to sync

#### Verify

- Visit [photos.google.com](https://photos.google.com) on a computer
- Confirm recent photos and videos are present

---

### Step 3: ADB Local Backup to Your Computer

This creates a local `.ab` file containing apps, their data (if allowed), and shared storage.

#### What It Captures

- APK files of installed apps
- App data for apps that allow backup
- Shared storage (`Downloads`, `Pictures`, `DCIM`, `Documents`, etc.)
- System settings, Wi-Fi networks, wallpaper, some launcher settings

#### What It Does NOT Capture

Apps that set `android:allowBackup="false"` are excluded. Common examples:

- WhatsApp
- Signal
- Telegram (partial)
- Most banking apps
- Many password managers
- Some games
- Apps with device-specific crypto keys

On **Android 12+**, Google further restricted `adb backup`, so even more apps may be excluded.

---

#### Install ADB

**macOS:**

```bash
brew install android-platform-tools
```

**Linux:**

```bash
sudo apt install android-tools-adb android-tools-fastboot
```

**Windows:**

1. Download **SDK Platform Tools** from Google
2. Extract to a folder such as `C:\platform-tools`
3. Add that folder to your system PATH

---

#### Enable USB Debugging on the Pixel

1. Open **Settings → About phone**
2. Tap **Build number** 7 times until Developer options are enabled
3. Go to **Settings → System → Developer options**
4. Turn on **USB debugging**

---

#### Connect and Authorize

Plug the phone into your computer with a USB cable.

```bash
adb devices
```

You should see your phone listed with a `device` status. On the phone, tap **Allow** and check **Always allow from this computer**.

---

#### Run the Full Backup

```bash
adb backup -apk -shared -all -system -keyvalue -f pixel6_full_backup.ab
```

| Flag | Meaning |
| --- | --- |
| `-apk` | Include APK files so apps can be reinstalled |
| `-shared` | Include shared storage (photos, downloads, documents) |
| `-all` | Include all apps that allow backup |
| `-system` | Include system apps |
| `-keyvalue` | Include key/value backups (settings, etc.) |
| `-f path` | Output file path |

Alternative without system apps (smaller, fewer restore conflicts):

```bash
adb backup -apk -shared -all -nosystem -f pixel6_user_backup.ab
```

#### On the Phone

A full-screen prompt appears:

1. Optionally set a backup password (recommended for encryption)
2. Tap **Back up my data**
3. Wait. This can take 10 minutes to over an hour depending on storage size.

Do not unplug the phone during the process.

---

#### Verify the `.ab` File

Check the file size:

```bash
ls -lh pixel6_full_backup.ab
```

A valid backup is usually several GB. A **0-byte file means nothing was backed up**.

Peek at the header:

```bash
head -c 24 pixel6_full_backup.ab | cat -v
```

It should start with `ANDROID BACKUP`.

---

#### Extract the `.ab` File

The `.ab` file is a compressed and possibly encrypted archive. Use **Android Backup Extractor (abe)** to inspect it.

Download and unpack:

```bash
wget https://github.com/nelenkov/android-backup-extractor/releases/download/latest/abe.jar
java -jar abe.jar unpack pixel6_full_backup.ab backup.tar [your_password]
tar -tvf backup.tar
```

If no password was set and the backup is zlib-compressed:

```bash
dd if=pixel6_full_backup.ab bs=1 skip=24 | zlib-flate -uncompress | tar -tvf -
```

On macOS, install `zlib-flate` first:

```bash
brew install qpdf
```

---

#### Restore from the `.ab` File

On a fresh or test phone:

```bash
adb restore pixel6_full_backup.ab
```

You will be prompted on the phone. The restore may take a long time.

**Warning:** Only restore to the same or very similar Android version. Cross-version restores often fail or cause crashes.

---

### Step 4: Back Up Apps That Opt Out Individually

These apps usually exclude themselves from Google and ADB backups. Export from each one.

| App | How to Export |
| --- | --- |
| **WhatsApp** | Settings → Chats → Chat backup → Back up to Google Drive |
| **Signal** | Settings → Chats → Backups → enable and save passphrase |
| **Telegram** | Settings → Advanced → Export Telegram data (or rely on cloud chats) |
| **Google Authenticator** | Use transfer/export codes; consider migrating to Aegis for better backups |
| **Password managers** | Bitwarden, 1Password, etc.: export encrypted vault |
| **Banking apps** | Usually no export; note balances and transactions separately |
| **Games** | Check Play Games cloud save or in-game account |

---

### Step 5: SMS and Call Logs Local Backup

Use **SMS Backup & Restore** from the Play Store:

1. Back up SMS and call logs to Google Drive, Dropbox, or local storage
2. Verify the backup file exists and has a recent timestamp

---

### Step 6: Google Takeout

For all Google service data:

1. Go to [takeout.google.com](https://takeout.google.com)
2. Select services: Drive, Gmail, Photos, Calendar, Contacts, YouTube, etc.
3. Create export and download the archive

---

## Path 2: True Full Image Backup

This is the only way to get a bit-for-bit copy of **everything**.

**Critical:** Unlocking the bootloader **erases all data** on the phone. You must complete Path 1 first.

### Step 1: Complete Path 1 First

Make sure your Google One, ADB, app-specific, and Google Takeout backups are done and verified before proceeding.

---

### Step 2: Unlock the Bootloader

```bash
adb reboot bootloader
fastboot flashing unlock
```

Confirm the unlock on the phone screen. This wipes the device.

---

### Step 3: Install a Custom Recovery

Flash TWRP or a LineageOS recovery that supports Pixel 6. Check [twrp.me](https://twrp.me) for current Pixel 6 support.

Example with TWRP image:

```bash
fastboot boot twrp-pixel6.img
```

Or flash it permanently:

```bash
fastboot flash recovery twrp-pixel6.img
```

---

### Step 4: Create a NANDroid Full Backup

1. Boot into recovery
2. Select **Backup**
3. Select all partitions: `Boot`, `System`, `Data`, `Vendor`, etc.
4. Store to an external USB drive, SD card, or push to your computer via ADB

This creates a complete image of your phone.

---

### Alternative: Root with Magisk and Pull Partitions

After unlocking the bootloader and rooting:

```bash
adb shell
su
tar -cvpzf /sdcard/data_backup.tar.gz /data/data /data/app /data/system
```

Then pull it to your computer:

```bash
adb pull /sdcard/data_backup.tar.gz
```

---

### Verify Path 2

- Boot the phone from recovery successfully after the backup
- Check the backup archive size matches expected used storage
- Restore the backup to confirm it works (test on the same device only after you have a working backup)

---

## Recommended Workflow Summary

| Priority | Method | What It Covers |
| --- | --- | --- |
| 1 | Google One backup | System, most app data, settings, call logs, SMS |
| 2 | Google Photos sync | Photos and videos |
| 3 | ADB local backup | Local copy of apps, allowed app data, shared storage |
| 4 | App-specific exports | WhatsApp, Signal, auth apps, password managers, games |
| 5 | SMS Backup & Restore | Local SMS and call log archive |
| 6 | Google Takeout | All Google service data |
| 7 | Custom recovery NANDroid | True full image backup (requires root/unlocked bootloader) |

---

## Final Checklist

- [ ] Google One backup completed and timestamp verified
- [ ] Google Photos fully synced
- [ ] ADB backup created and file size is non-zero
- [ ] WhatsApp, Signal, and other excluded apps exported
- [ ] Authenticator codes transferred or backed up
- [ ] Password manager vault exported
- [ ] SMS/call logs backed up
- [ ] Google Takeout archive downloaded
- [ ] Backup files copied to at least two locations (cloud + local drive)
- [ ] If going the root route: bootloader unlocked and NANDroid backup created

---

## Common ADB Backup Issues

| Problem | Fix |
| --- | --- |
| `adb: unable to connect` | Check USB cable, re-authorize debugging, try `adb kill-server && adb start-server` |
| Backup file is 0 bytes | Some apps or the system refused. Try `-nosystem` or exclude problem apps |
| Backup fails partway through | Reboot phone, reconnect, retry |
| Restore fails | Ensure target phone runs the same Android version |
| Encrypted backup won't extract | Use the exact password with `abe.jar` |

---

## Notes

- **Use a wired connection**, not wireless ADB, for large backups.
- **Set a backup password** on the phone prompt to encrypt the `.ab` file.
- **Store backups in at least two places** to protect against data loss.
- **Test restores on a spare device** when possible.
- ADB backup on a Pixel 6 running Android 12+ is useful but **not a true full image**. For that, use custom recovery.
