{ runCommand, dbip-city-lite, python3 }:

# db-ip City Lite relabelled as GeoLite2-City.
# The otel geoip processor accepts only the two MaxMind City type names
# and refuses DBIP-City-Lite, though the record layout matches.
# Metadata sits after the search tree and data section,
# so resizing its type string by one byte moves no offset anything points at.
runCommand "geoip-city-db-${dbip-city-lite.version}" { nativeBuildInputs = [ python3 ]; } ''
  mkdir -p $out/share/geoip
  python3 - ${dbip-city-lite}/share/dbip/dbip-city-lite.mmdb $out/share/geoip/city.mmdb <<'PY'
  import sys
  src, dst = sys.argv[1:]
  data = open(src, "rb").read()
  marker = data.rindex(b"\xab\xcd\xefMaxMind.com")
  old = b"\x4eDBIP-City-Lite"
  new = b"\x4dGeoLite2-City"
  meta = data[marker:]
  assert meta.count(old) == 1, "database_type string not found once"
  open(dst, "wb").write(data[:marker] + meta.replace(old, new))
  PY
''
