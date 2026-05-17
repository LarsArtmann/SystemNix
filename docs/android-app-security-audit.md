# Android App Decompilation & Security Analysis

Decompiling and auditing your own installed apps for security issues.

## Decompile APKs

```bash
# 1. Extract APK from device
adb shell pm list packages -f              # Find package path
adb pull /data/app/~~.../base.apk app.apk  # Pull APK

# 2. Decompile with apktool (resources + manifest)
apktool d app.apk -o app_decompiled

# 3. Decompile to Java with jadx (readable source)
jadx app.apk -d app_jadx

# 4. Convert to dex → jar → Java (alternative chain)
dex2jar app.apk -o app.jar
jd-gui app.jar                              # GUI viewer
```

| Tool | Purpose |
|------|---------|
| **apktool** | Decode resources, AndroidManifest.xml, smali bytecode |
| **jadx** | Dex → decompiled Java (best readability) |
| **dex2jar** | .dex → .jar conversion |
| **baksmali** | Disassemble to smali (bytecode level) |

## Security Analysis Checklist

After decompiling, look for:

| Category | What to check | Where |
|----------|---------------|-------|
| **Hardcoded secrets** | API keys, tokens, passwords in source | `grep -ri "api_key\|secret\|token\|password" app_jadx/` |
| **Insecure storage** | SharedPreferences in plaintext, SQLCipher absent | Search for `SharedPreferences`, `getWritableDatabase` |
| **Cleartext traffic** | HTTP instead of HTTPS | `AndroidManifest.xml` → `usesCleartextTraffic`, grep `http://` |
| **Weak crypto** | ECB mode, MD5/SHA1 for passwords, hardcoded IVs | Search for `Cipher.getInstance`, `MessageDigest` |
| **Certificate pinning** | Missing or bypassable | Search for `CertificatePinner`, `TrustManager` |
| **Intent injection** | Exported activities/services without permission checks | `AndroidManifest.xml` → `exported="true"` |
| **SQL injection** | String concatenation in queries | Search for `rawQuery`, `execSQL` with string formatting |
| **Logging leaks** | Sensitive data in Logcat | Search for `Log.d\|Log.i\|Log.e` with sensitive params |
| **WebView risks** | JS enabled + addJavascriptInterface | Search for `setJavaScriptEnabled`, `addJavascriptInterface` |
| **Insecure intents** | Implicit intents for sensitive actions | Search for `ACTION_SEND`, `startActivity` patterns |

## Automated Scanning Tools

```bash
# MobSF — full automated analysis (Docker)
docker run -it -p 8000:8000 opensecurity/mobsf:latest
# Upload APK via web UI at localhost:8000

# Quark — behavioral analysis
pip install quark-engine
quark -a app.apk -o report.html

# Drozer — runtime intent injection testing (on device)
drozer console connect
run app.package.attacksurface com.example.app
```

| Tool | What it finds |
|------|---------------|
| **MobSF** | Full SAST+DAST: secrets, misconfigurations, permissions, crypto issues |
| **Quark** | Known malicious behavior patterns in Dalvik bytecode |
| **Drozer** | Runtime attack surface (exported components, content providers) |
| **nuclei** (mobile templates) | Known CVEs in packaged libraries |

## Bulk Extraction (All Apps)

```bash
# List all installed packages
adb shell pm list packages -3  # Third-party only

# Pull all APKs
for pkg in $(adb shell pm list packages -3 | sed 's/package://'); do
  path=$(adb shell pm path "$pkg" | sed 's/package://')
  adb pull "$path" "apks/${pkg}.apk"
done

# Batch analyze with jadx
find apks/ -name "*.apk" -exec jadx {} -d "analysis/{name}" \;
```

## Tips

- **Focus on third-party apps** — system apps are signed by the OEM and harder to meaningfully audit
- **Check third-party SDKs** — most vulnerabilities come from bundled analytics/ad SDKs, not the app itself
- **Network analysis** complements decompilation — use **mitmproxy** or **Charles Proxy** to see what data apps actually transmit at runtime
- **Root/Magisk** needed for some runtime tests (Drozer, Frida hooking)
- **Frida** (`frida -U -f com.app --script hook.js`) enables runtime method hooking to bypass cert pinning and observe crypto operations in real time
