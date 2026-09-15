#!/usr/bin/env python3
"""读 APK 里 AndroidManifest.xml 的 versionCode。

安卓打包后清单是二进制 XML（AXML），这里不依赖 aapt/aapt2，也不依赖安卓 SDK——
发布流程要在任何有 python3 的机器上都能跑这条校验。

AXML 是一串 chunk：XML 头 → 字符串池 → 资源映射表 → 若干节点。取第一个 StartElement
（就是 <manifest>），在它的属性表里找版本号。两个容易踩的地方：
1. 属性名存的是**字符串池下标**，框架属性的资源 ID 要靠资源映射表换算
   （下标 17 → 0x0101021b），不能直接拿下标当资源 ID。
2. 不能在字节流里直接搜 0x0101021b：资源映射表本身就是一串框架属性的资源 ID，
   搜到的永远是它。
"""

import struct
import sys
import zipfile

XML_HEADER_SIZE = 8
CHUNK_HEADER_SIZE = 8
RES_XML_RESOURCE_MAP_TYPE = 0x0180
RES_XML_START_ELEMENT_TYPE = 0x0102
START_ELEMENT_EXT_OFFSET = 16
ATTR_NAME_OFFSET = 4
ATTR_DATA_TYPE_OFFSET = 15
ATTR_VALUE_OFFSET = 16
ATTR_SIZE = 20
TYPE_INT_DEC = 0x10
TYPE_INT_HEX = 0x11
VERSION_CODE_ATTR = 0x0101021B


def walk_chunks(data):
    offset = XML_HEADER_SIZE
    while offset + CHUNK_HEADER_SIZE <= len(data):
        chunk_type, _header_size, chunk_size = struct.unpack_from("<HHI", data, offset)
        if chunk_size < CHUNK_HEADER_SIZE or offset + chunk_size > len(data):
            return
        yield chunk_type, offset, chunk_size
        offset += chunk_size


def resource_map(data):
    """资源映射表：第 n 项是字符串池里第 n 个字符串对应的资源 ID。"""
    for chunk_type, offset, chunk_size in walk_chunks(data):
        if chunk_type == RES_XML_RESOURCE_MAP_TYPE:
            count = (chunk_size - CHUNK_HEADER_SIZE) // 4
            return struct.unpack_from(f"<{count}I", data, offset + CHUNK_HEADER_SIZE)
    return ()


def version_code(apk_path):
    with zipfile.ZipFile(apk_path) as apk:
        data = apk.read("AndroidManifest.xml")
    ids = resource_map(data)
    for chunk_type, offset, _chunk_size in walk_chunks(data):
        if chunk_type != RES_XML_START_ELEMENT_TYPE:
            continue
        attr_start, attr_size, attr_count = struct.unpack_from("<HHH", data, offset + 24)
        for index in range(attr_count):
            attr = offset + START_ELEMENT_EXT_OFFSET + attr_start + index * attr_size
            name_index = struct.unpack_from("<I", data, attr + ATTR_NAME_OFFSET)[0]
            if name_index >= len(ids) or ids[name_index] != VERSION_CODE_ATTR:
                continue
            data_type = data[attr + ATTR_DATA_TYPE_OFFSET]
            if data_type not in (TYPE_INT_DEC, TYPE_INT_HEX):
                raise SystemExit(f"{apk_path}: versionCode 不是整数（类型 0x{data_type:02x}）")
            return struct.unpack_from("<I", data, attr + ATTR_VALUE_OFFSET)[0]
        break
    raise SystemExit(f"{apk_path}: 读不出 versionCode")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("用法: apk_version_code.py <apk>")
    print(version_code(sys.argv[1]))
