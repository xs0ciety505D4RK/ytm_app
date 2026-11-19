"""Patch hasil `flutter create` supaya pemutaran di background jalan
(foreground service audio_service + izin) dan app bernama YTM Glass."""
import glob
import pathlib
import re

m = pathlib.Path('android/app/src/main/AndroidManifest.xml')
s = m.read_text()

if 'xmlns:tools' not in s:
    s = s.replace('<manifest ', '<manifest xmlns:tools="http://schemas.android.com/tools" ', 1)

perms = ''.join(
    f'    <uses-permission android:name="android.permission.{p}"/>\n'
    for p in ['INTERNET', 'WAKE_LOCK', 'FOREGROUND_SERVICE',
              'FOREGROUND_SERVICE_MEDIA_PLAYBACK', 'POST_NOTIFICATIONS']
)
s = s.replace('<application', perms + '    <application', 1)

svc = '''        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService"/>
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON"/>
            </intent-filter>
        </receiver>
'''
s = s.replace('</application>', svc + '    </application>', 1)
s = s.replace('android:label="ytm_glass"', 'android:label="YTM Glass"')
s = s.replace('<application', '<application android:usesCleartextTraffic="true"', 1)
m.write_text(s)

for f in glob.glob('android/app/src/main/kotlin/**/MainActivity.kt', recursive=True):
    path = pathlib.Path(f)
    pkg = re.search(r'^package\s+(\S+)', path.read_text(), re.M).group(1)
    path.write_text(
        f'package {pkg}\n\n'
        'import com.ryanheise.audioservice.AudioServiceActivity\n\n'
        'class MainActivity : AudioServiceActivity()\n'
    )
print('Android patched')
