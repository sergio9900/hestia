const VERSION_NAME = /versionName\s*=\s*"([^"]+)"/;
const VERSION_CODE = /versionCode\s*=\s*(\d+)/;

module.exports.readVersion = (contents) => contents.match(VERSION_NAME)[1]

module.exports.writeVersion = (contents, version) => {
    const [major, minor, patch] = version.split('-')[0].split('.').map((n) => parseInt(n, 10));
    // 1.2.3 -> 10203 (siempre creciente mientras minor y patch , 100)
    const code = major * 10000 + minor * 100 + patch;
    return contents.replace(VERSION_NAME, `versionName = "${version}"`).replace(VERSION_CODE, `versionCode = ${code}`);
}
