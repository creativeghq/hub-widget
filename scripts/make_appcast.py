"""Sign dist/HubWidget-$V.zip with the Sparkle EdDSA key and write dist/appcast.xml (one item: this release)."""
import base64
import os
from email.utils import formatdate

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

version = os.environ["V"]
build = os.environ["BUILD"]
zip_name = f"HubWidget-{version}.zip"
zip_path = os.path.join("dist", zip_name)
data = open(zip_path, "rb").read()

seed = base64.b64decode(os.environ["SPARKLE_ED_PRIVATE_KEY"].strip())
key = Ed25519PrivateKey.from_private_bytes(seed[:32])
signature = base64.b64encode(key.sign(data)).decode()

url = f"https://github.com/creativeghq/hub-widget/releases/download/v{version}/{zip_name}"
appcast = f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Hub Widget</title>
    <item>
      <title>Version {version}</title>
      <pubDate>{formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/creativeghq/hub-widget/releases/tag/v{version}</sparkle:releaseNotesLink>
      <enclosure url="{url}" length="{len(data)}" type="application/octet-stream" sparkle:edSignature="{signature}"/>
    </item>
  </channel>
</rss>
"""
open(os.path.join("dist", "appcast.xml"), "w").write(appcast)
print(f"signed {zip_name} ({len(data)} bytes), build {build}")
