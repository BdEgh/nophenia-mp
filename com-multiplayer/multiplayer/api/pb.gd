class_name Api extends Object
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2023, Oleg Malyavkin
# All rights reserved.

const PROTO_VERSION = 3

const DEBUG_TAB : String = "  "

enum PB_ERR {
    NO_ERRORS = 0,
    VARINT_NOT_FOUND = -1,
    REPEATED_COUNT_NOT_FOUND = -2,
    REPEATED_COUNT_MISMATCH = -3,
    LENGTHDEL_SIZE_NOT_FOUND = -4,
    LENGTHDEL_SIZE_MISMATCH = -5,
    PACKAGE_SIZE_MISMATCH = -6,
    UNDEFINED_STATE = -7,
    PARSE_INCOMPLETE = -8,
    REQUIRED_FIELDS = -9
}

enum PB_DATA_TYPE {
    INT32 = 0,
    SINT32 = 1,
    UINT32 = 2,
    INT64 = 3,
    SINT64 = 4,
    UINT64 = 5,
    BOOL = 6,
    ENUM = 7,
    FIXED32 = 8,
    SFIXED32 = 9,
    FLOAT = 10,
    FIXED64 = 11,
    SFIXED64 = 12,
    DOUBLE = 13,
    STRING = 14,
    BYTES = 15,
    MESSAGE = 16,
    MAP = 17
}

const DEFAULT_VALUES_2 = {
    PB_DATA_TYPE.INT32: null,
    PB_DATA_TYPE.SINT32: null,
    PB_DATA_TYPE.UINT32: null,
    PB_DATA_TYPE.INT64: null,
    PB_DATA_TYPE.SINT64: null,
    PB_DATA_TYPE.UINT64: null,
    PB_DATA_TYPE.BOOL: null,
    PB_DATA_TYPE.ENUM: null,
    PB_DATA_TYPE.FIXED32: null,
    PB_DATA_TYPE.SFIXED32: null,
    PB_DATA_TYPE.FLOAT: null,
    PB_DATA_TYPE.FIXED64: null,
    PB_DATA_TYPE.SFIXED64: null,
    PB_DATA_TYPE.DOUBLE: null,
    PB_DATA_TYPE.STRING: null,
    PB_DATA_TYPE.BYTES: null,
    PB_DATA_TYPE.MESSAGE: null,
    PB_DATA_TYPE.MAP: null
}

const DEFAULT_VALUES_3 = {
    PB_DATA_TYPE.INT32: 0,
    PB_DATA_TYPE.SINT32: 0,
    PB_DATA_TYPE.UINT32: 0,
    PB_DATA_TYPE.INT64: 0,
    PB_DATA_TYPE.SINT64: 0,
    PB_DATA_TYPE.UINT64: 0,
    PB_DATA_TYPE.BOOL: false,
    PB_DATA_TYPE.ENUM: 0,
    PB_DATA_TYPE.FIXED32: 0,
    PB_DATA_TYPE.SFIXED32: 0,
    PB_DATA_TYPE.FLOAT: 0.0,
    PB_DATA_TYPE.FIXED64: 0,
    PB_DATA_TYPE.SFIXED64: 0,
    PB_DATA_TYPE.DOUBLE: 0.0,
    PB_DATA_TYPE.STRING: "",
    PB_DATA_TYPE.BYTES: [],
    PB_DATA_TYPE.MESSAGE: null,
    PB_DATA_TYPE.MAP: []
}

enum PB_TYPE {
    VARINT = 0,
    FIX64 = 1,
    LENGTHDEL = 2,
    STARTGROUP = 3,
    ENDGROUP = 4,
    FIX32 = 5,
    UNDEFINED = 8
}

enum PB_RULE {
    OPTIONAL = 0,
    REQUIRED = 1,
    REPEATED = 2,
    RESERVED = 3
}

enum PB_SERVICE_STATE {
    FILLED = 0,
    UNFILLED = 1
}

class PBField:
    func _init(a_name : String, a_type : int, a_rule : int, a_tag : int, packed : bool, a_value = null):
        name = a_name
        type = a_type
        rule = a_rule
        tag = a_tag
        option_packed = packed
        value = a_value
        
    var name : String
    var type : int
    var rule : int
    var tag : int
    var option_packed : bool
    var value
    var is_map_field : bool = false
    var option_default : bool = false

class PBTypeTag:
    var ok : bool = false
    var type : int
    var tag : int
    var offset : int

class PBServiceField:
    var field : PBField
    var func_ref = null
    var state : int = PB_SERVICE_STATE.UNFILLED

class PBPacker:
    static func convert_signed(n : int) -> int:
        if n < -2147483648:
            return (n << 1) ^ (n >> 63)
        else:
            return (n << 1) ^ (n >> 31)

    static func deconvert_signed(n : int) -> int:
        if n & 0x01:
            return ~(n >> 1)
        else:
            return (n >> 1)

    static func pack_varint(value) -> PackedByteArray:
        var varint : PackedByteArray = PackedByteArray()
        if typeof(value) == TYPE_BOOL:
            if value:
                value = 1
            else:
                value = 0
        for _i in range(9):
            var b = value & 0x7F
            value >>= 7
            if value:
                varint.append(b | 0x80)
            else:
                varint.append(b)
                break
        if varint.size() == 9 && (varint[8] & 0x80 != 0):
            varint.append(0x01)
        return varint

    static func pack_bytes(value, count : int, data_type : int) -> PackedByteArray:
        var bytes : PackedByteArray = PackedByteArray()
        if data_type == PB_DATA_TYPE.FLOAT:
            var spb : StreamPeerBuffer = StreamPeerBuffer.new()
            spb.put_float(value)
            bytes = spb.get_data_array()
        elif data_type == PB_DATA_TYPE.DOUBLE:
            var spb : StreamPeerBuffer = StreamPeerBuffer.new()
            spb.put_double(value)
            bytes = spb.get_data_array()
        else:
            for _i in range(count):
                bytes.append(value & 0xFF)
                value >>= 8
        return bytes

    static func unpack_bytes(bytes : PackedByteArray, index : int, count : int, data_type : int):
        if data_type == PB_DATA_TYPE.FLOAT:
            return bytes.decode_float(index)
        elif data_type == PB_DATA_TYPE.DOUBLE:
            return bytes.decode_double(index)
        else:
            # Convert to big endian
            var slice: PackedByteArray = bytes.slice(index, index + count)
            slice.reverse()
            return slice

    static func unpack_varint(varint_bytes) -> int:
        var value : int = 0
        var i: int = varint_bytes.size() - 1
        while i > -1:
            value = (value << 7) | (varint_bytes[i] & 0x7F)
            i -= 1
        return value

    static func pack_type_tag(type : int, tag : int) -> PackedByteArray:
        return pack_varint((tag << 3) | type)

    static func isolate_varint(bytes : PackedByteArray, index : int) -> PackedByteArray:
        var i: int = index
        while i <= index + 10: # Protobuf varint max size is 10 bytes
            if !(bytes[i] & 0x80):
                return bytes.slice(index, i + 1)
            i += 1
        return [] # Unreachable

    static func unpack_type_tag(bytes : PackedByteArray, index : int) -> PBTypeTag:
        var varint_bytes : PackedByteArray = isolate_varint(bytes, index)
        var result : PBTypeTag = PBTypeTag.new()
        if varint_bytes.size() != 0:
            result.ok = true
            result.offset = varint_bytes.size()
            var unpacked : int = unpack_varint(varint_bytes)
            result.type = unpacked & 0x07
            result.tag = unpacked >> 3
        return result

    static func pack_length_delimeted(type : int, tag : int, bytes : PackedByteArray) -> PackedByteArray:
        var result : PackedByteArray = pack_type_tag(type, tag)
        result.append_array(pack_varint(bytes.size()))
        result.append_array(bytes)
        return result

    static func pb_type_from_data_type(data_type : int) -> int:
        if data_type == PB_DATA_TYPE.INT32 || data_type == PB_DATA_TYPE.SINT32 || data_type == PB_DATA_TYPE.UINT32 || data_type == PB_DATA_TYPE.INT64 || data_type == PB_DATA_TYPE.SINT64 || data_type == PB_DATA_TYPE.UINT64 || data_type == PB_DATA_TYPE.BOOL || data_type == PB_DATA_TYPE.ENUM:
            return PB_TYPE.VARINT
        elif data_type == PB_DATA_TYPE.FIXED32 || data_type == PB_DATA_TYPE.SFIXED32 || data_type == PB_DATA_TYPE.FLOAT:
            return PB_TYPE.FIX32
        elif data_type == PB_DATA_TYPE.FIXED64 || data_type == PB_DATA_TYPE.SFIXED64 || data_type == PB_DATA_TYPE.DOUBLE:
            return PB_TYPE.FIX64
        elif data_type == PB_DATA_TYPE.STRING || data_type == PB_DATA_TYPE.BYTES || data_type == PB_DATA_TYPE.MESSAGE || data_type == PB_DATA_TYPE.MAP:
            return PB_TYPE.LENGTHDEL
        else:
            return PB_TYPE.UNDEFINED

    static func pack_field(field : PBField) -> PackedByteArray:
        var type : int = pb_type_from_data_type(field.type)
        var type_copy : int = type
        if field.rule == PB_RULE.REPEATED && field.option_packed:
            type = PB_TYPE.LENGTHDEL
        var head : PackedByteArray = pack_type_tag(type, field.tag)
        var data : PackedByteArray = PackedByteArray()
        if type == PB_TYPE.VARINT:
            var value
            if field.rule == PB_RULE.REPEATED:
                for v in field.value:
                    data.append_array(head)
                    if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
                        value = convert_signed(v)
                    else:
                        value = v
                    data.append_array(pack_varint(value))
                return data
            else:
                if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
                    value = convert_signed(field.value)
                else:
                    value = field.value
                data = pack_varint(value)
        elif type == PB_TYPE.FIX32:
            if field.rule == PB_RULE.REPEATED:
                for v in field.value:
                    data.append_array(head)
                    data.append_array(pack_bytes(v, 4, field.type))
                return data
            else:
                data.append_array(pack_bytes(field.value, 4, field.type))
        elif type == PB_TYPE.FIX64:
            if field.rule == PB_RULE.REPEATED:
                for v in field.value:
                    data.append_array(head)
                    data.append_array(pack_bytes(v, 8, field.type))
                return data
            else:
                data.append_array(pack_bytes(field.value, 8, field.type))
        elif type == PB_TYPE.LENGTHDEL:
            if field.rule == PB_RULE.REPEATED:
                if type_copy == PB_TYPE.VARINT:
                    if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
                        var signed_value : int
                        for v in field.value:
                            signed_value = convert_signed(v)
                            data.append_array(pack_varint(signed_value))
                    else:
                        for v in field.value:
                            data.append_array(pack_varint(v))
                    return pack_length_delimeted(type, field.tag, data)
                elif type_copy == PB_TYPE.FIX32:
                    for v in field.value:
                        data.append_array(pack_bytes(v, 4, field.type))
                    return pack_length_delimeted(type, field.tag, data)
                elif type_copy == PB_TYPE.FIX64:
                    for v in field.value:
                        data.append_array(pack_bytes(v, 8, field.type))
                    return pack_length_delimeted(type, field.tag, data)
                elif field.type == PB_DATA_TYPE.STRING:
                    for v in field.value:
                        var obj = v.to_utf8_buffer()
                        data.append_array(pack_length_delimeted(type, field.tag, obj))
                    return data
                elif field.type == PB_DATA_TYPE.BYTES:
                    for v in field.value:
                        data.append_array(pack_length_delimeted(type, field.tag, v))
                    return data
                elif typeof(field.value[0]) == TYPE_OBJECT:
                    for v in field.value:
                        var obj : PackedByteArray = v.to_bytes()
                        data.append_array(pack_length_delimeted(type, field.tag, obj))
                    return data
            else:
                if field.type == PB_DATA_TYPE.STRING:
                    var str_bytes : PackedByteArray = field.value.to_utf8_buffer()
                    if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
                        data.append_array(str_bytes)
                        return pack_length_delimeted(type, field.tag, data)
                if field.type == PB_DATA_TYPE.BYTES:
                    if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
                        data.append_array(field.value)
                        return pack_length_delimeted(type, field.tag, data)
                elif typeof(field.value) == TYPE_OBJECT:
                    var obj : PackedByteArray = field.value.to_bytes()
                    if obj.size() > 0:
                        data.append_array(obj)
                    return pack_length_delimeted(type, field.tag, data)
                else:
                    pass
        if data.size() > 0:
            head.append_array(data)
            return head
        else:
            return data

    static func skip_unknown_field(bytes : PackedByteArray, offset : int, type : int) -> int:
        if type == PB_TYPE.VARINT:
            return offset + isolate_varint(bytes, offset).size()
        if type == PB_TYPE.FIX64:
            return offset + 8
        if type == PB_TYPE.LENGTHDEL:
            var length_bytes : PackedByteArray = isolate_varint(bytes, offset)
            var length : int = unpack_varint(length_bytes)
            return offset + length_bytes.size() + length
        if type == PB_TYPE.FIX32:
            return offset + 4
        return PB_ERR.UNDEFINED_STATE

    static func unpack_field(bytes : PackedByteArray, offset : int, field : PBField, type : int, message_func_ref) -> int:
        if field.rule == PB_RULE.REPEATED && type != PB_TYPE.LENGTHDEL && field.option_packed:
            var count = isolate_varint(bytes, offset)
            if count.size() > 0:
                offset += count.size()
                count = unpack_varint(count)
                if type == PB_TYPE.VARINT:
                    var val
                    var counter = offset + count
                    while offset < counter:
                        val = isolate_varint(bytes, offset)
                        if val.size() > 0:
                            offset += val.size()
                            val = unpack_varint(val)
                            if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
                                val = deconvert_signed(val)
                            elif field.type == PB_DATA_TYPE.BOOL:
                                if val:
                                    val = true
                                else:
                                    val = false
                            field.value.append(val)
                        else:
                            return PB_ERR.REPEATED_COUNT_MISMATCH
                    return offset
                elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
                    var type_size
                    if type == PB_TYPE.FIX32:
                        type_size = 4
                    else:
                        type_size = 8
                    var val
                    var counter = offset + count
                    while offset < counter:
                        if (offset + type_size) > bytes.size():
                            return PB_ERR.REPEATED_COUNT_MISMATCH
                        val = unpack_bytes(bytes, offset, type_size, field.type)
                        offset += type_size
                        field.value.append(val)
                    return offset
            else:
                return PB_ERR.REPEATED_COUNT_NOT_FOUND
        else:
            if type == PB_TYPE.VARINT:
                var val = isolate_varint(bytes, offset)
                if val.size() > 0:
                    offset += val.size()
                    val = unpack_varint(val)
                    if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
                        val = deconvert_signed(val)
                    elif field.type == PB_DATA_TYPE.BOOL:
                        if val:
                            val = true
                        else:
                            val = false
                    if field.rule == PB_RULE.REPEATED:
                        field.value.append(val)
                    else:
                        field.value = val
                else:
                    return PB_ERR.VARINT_NOT_FOUND
                return offset
            elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
                var type_size
                if type == PB_TYPE.FIX32:
                    type_size = 4
                else:
                    type_size = 8
                var val
                if (offset + type_size) > bytes.size():
                    return PB_ERR.REPEATED_COUNT_MISMATCH
                val = unpack_bytes(bytes, offset, type_size, field.type)
                offset += type_size
                if field.rule == PB_RULE.REPEATED:
                    field.value.append(val)
                else:
                    field.value = val
                return offset
            elif type == PB_TYPE.LENGTHDEL:
                var inner_size = isolate_varint(bytes, offset)
                if inner_size.size() > 0:
                    offset += inner_size.size()
                    inner_size = unpack_varint(inner_size)
                    if inner_size >= 0:
                        if inner_size + offset > bytes.size():
                            return PB_ERR.LENGTHDEL_SIZE_MISMATCH
                        if message_func_ref != null:
                            var message = message_func_ref.call()
                            if inner_size > 0:
                                var sub_offset = message.from_bytes(bytes, offset, inner_size + offset)
                                if sub_offset > 0:
                                    if sub_offset - offset >= inner_size:
                                        offset = sub_offset
                                        return offset
                                    else:
                                        return PB_ERR.LENGTHDEL_SIZE_MISMATCH
                                return sub_offset
                            else:
                                return offset
                        elif field.type == PB_DATA_TYPE.STRING:
                            var str_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
                            if field.rule == PB_RULE.REPEATED:
                                field.value.append(str_bytes.get_string_from_utf8())
                            else:
                                field.value = str_bytes.get_string_from_utf8()
                            return offset + inner_size
                        elif field.type == PB_DATA_TYPE.BYTES:
                            var val_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
                            if field.rule == PB_RULE.REPEATED:
                                field.value.append(val_bytes)
                            else:
                                field.value = val_bytes
                            return offset + inner_size
                    else:
                        return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
                else:
                    return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
        return PB_ERR.UNDEFINED_STATE

    static func unpack_message(data, bytes : PackedByteArray, offset : int, limit : int) -> int:
        while true:
            var tt : PBTypeTag = unpack_type_tag(bytes, offset)
            if tt.ok:
                offset += tt.offset
                if data.has(tt.tag):
                    var service : PBServiceField = data[tt.tag]
                    var type : int = pb_type_from_data_type(service.field.type)
                    if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && service.field.rule == PB_RULE.REPEATED && service.field.option_packed):
                        var res : int = unpack_field(bytes, offset, service.field, type, service.func_ref)
                        if res > 0:
                            service.state = PB_SERVICE_STATE.FILLED
                            offset = res
                            if offset == limit:
                                return offset
                            elif offset > limit:
                                return PB_ERR.PACKAGE_SIZE_MISMATCH
                        elif res < 0:
                            return res
                        else:
                            break
                else:
                    var res : int = skip_unknown_field(bytes, offset, tt.type)
                    if res > 0:
                        offset = res
                        if offset == limit:
                            return offset
                        elif offset > limit:
                            return PB_ERR.PACKAGE_SIZE_MISMATCH
                    elif res < 0:
                        return res
                    else:
                        break							
            else:
                return offset
        return PB_ERR.UNDEFINED_STATE

    static func pack_message(data) -> PackedByteArray:
        var DEFAULT_VALUES
        if PROTO_VERSION == 2:
            DEFAULT_VALUES = DEFAULT_VALUES_2
        elif PROTO_VERSION == 3:
            DEFAULT_VALUES = DEFAULT_VALUES_3
        var result : PackedByteArray = PackedByteArray()
        var keys : Array = data.keys()
        keys.sort()
        for i in keys:
            if data[i].field.value != null:
                if data[i].state == PB_SERVICE_STATE.UNFILLED \
                && !data[i].field.is_map_field \
                && typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
                && data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
                    continue
                elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
                    continue
                result.append_array(pack_field(data[i].field))
            elif data[i].field.rule == PB_RULE.REQUIRED:
                print("Error: required field is not filled: Tag:", data[i].field.tag)
                return PackedByteArray()
        return result

    static func check_required(data) -> bool:
        var keys : Array = data.keys()
        for i in keys:
            if data[i].field.rule == PB_RULE.REQUIRED && data[i].state == PB_SERVICE_STATE.UNFILLED:
                return false
        return true

    static func construct_map(key_values):
        var result = {}
        for kv in key_values:
            result[kv.get_key()] = kv.get_value()
        return result
    
    static func tabulate(text : String, nesting : int) -> String:
        var tab : String = ""
        for _i in range(nesting):
            tab += DEBUG_TAB
        return tab + text
    
    static func value_to_string(value, field : PBField, nesting : int) -> String:
        var result : String = ""
        var text : String
        if field.type == PB_DATA_TYPE.MESSAGE:
            result += "{"
            nesting += 1
            text = message_to_string(value.data, nesting)
            if text != "":
                result += "\n" + text
                nesting -= 1
                result += tabulate("}", nesting)
            else:
                nesting -= 1
                result += "}"
        elif field.type == PB_DATA_TYPE.BYTES:
            result += "<"
            for i in range(value.size()):
                result += str(value[i])
                if i != (value.size() - 1):
                    result += ", "
            result += ">"
        elif field.type == PB_DATA_TYPE.STRING:
            result += "\"" + value + "\""
        elif field.type == PB_DATA_TYPE.ENUM:
            result += "ENUM::" + str(value)
        else:
            result += str(value)
        return result
    
    static func field_to_string(field : PBField, nesting : int) -> String:
        var result : String = tabulate(field.name + ": ", nesting)
        if field.type == PB_DATA_TYPE.MAP:
            if field.value.size() > 0:
                result += "(\n"
                nesting += 1
                for i in range(field.value.size()):
                    var local_key_value = field.value[i].data[1].field
                    result += tabulate(value_to_string(local_key_value.value, local_key_value, nesting), nesting) + ": "
                    local_key_value = field.value[i].data[2].field
                    result += value_to_string(local_key_value.value, local_key_value, nesting)
                    if i != (field.value.size() - 1):
                        result += ","
                    result += "\n"
                nesting -= 1
                result += tabulate(")", nesting)
            else:
                result += "()"
        elif field.rule == PB_RULE.REPEATED:
            if field.value.size() > 0:
                result += "[\n"
                nesting += 1
                for i in range(field.value.size()):
                    result += tabulate(str(i) + ": ", nesting)
                    result += value_to_string(field.value[i], field, nesting)
                    if i != (field.value.size() - 1):
                        result += ","
                    result += "\n"
                nesting -= 1
                result += tabulate("]", nesting)
            else:
                result += "[]"
        else:
            result += value_to_string(field.value, field, nesting)
        result += ";\n"
        return result
        
    static func message_to_string(data, nesting : int = 0) -> String:
        var DEFAULT_VALUES
        if PROTO_VERSION == 2:
            DEFAULT_VALUES = DEFAULT_VALUES_2
        elif PROTO_VERSION == 3:
            DEFAULT_VALUES = DEFAULT_VALUES_3
        var result : String = ""
        var keys : Array = data.keys()
        keys.sort()
        for i in keys:
            if data[i].field.value != null:
                if data[i].state == PB_SERVICE_STATE.UNFILLED \
                && !data[i].field.is_map_field \
                && typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
                && data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
                    continue
                elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
                    continue
                result += field_to_string(data[i].field, nesting)
            elif data[i].field.rule == PB_RULE.REQUIRED:
                result += data[i].field.name + ": " + "error"
        return result



############### USER DATA BEGIN ################


enum EAction {
    DELETE = 0,
    SET = 1,
    MERGE = 2
}

class TPosition:
    func _init():
        var service
        
        var __vector_default: Array[float] = []
        __vector = PBField.new("vector", PB_DATA_TYPE.FLOAT, PB_RULE.REPEATED, 1, true, __vector_default)
        service = PBServiceField.new()
        service.field = __vector
        data[__vector.tag] = service
        
    var data = {}
    
    var __vector: PBField
    func get_vector() -> Array[float]:
        return __vector.value
    func clear_vector() -> void:
        data[1].state = PB_SERVICE_STATE.UNFILLED
        __vector.value.clear()
    func add_vector(value : float) -> void:
        __vector.value.append(value)
    
    func _to_string() -> String:
        return PBPacker.message_to_string(data)
        
    func to_bytes() -> PackedByteArray:
        return PBPacker.pack_message(data)
        
    func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
        var cur_limit = bytes.size()
        if limit != -1:
            cur_limit = limit
        var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
        if result == cur_limit:
            if PBPacker.check_required(data):
                if limit == -1:
                    return PB_ERR.NO_ERRORS
            else:
                return PB_ERR.REQUIRED_FIELDS
        elif limit == -1 && result > 0:
            return PB_ERR.PARSE_INCOMPLETE
        return result
    
class TVelocity:
    func _init():
        var service
        
        var __vector_default: Array[float] = []
        __vector = PBField.new("vector", PB_DATA_TYPE.FLOAT, PB_RULE.REPEATED, 1, true, __vector_default)
        service = PBServiceField.new()
        service.field = __vector
        data[__vector.tag] = service
        
    var data = {}
    
    var __vector: PBField
    func get_vector() -> Array[float]:
        return __vector.value
    func clear_vector() -> void:
        data[1].state = PB_SERVICE_STATE.UNFILLED
        __vector.value.clear()
    func add_vector(value : float) -> void:
        __vector.value.append(value)
    
    func _to_string() -> String:
        return PBPacker.message_to_string(data)
        
    func to_bytes() -> PackedByteArray:
        return PBPacker.pack_message(data)
        
    func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
        var cur_limit = bytes.size()
        if limit != -1:
            cur_limit = limit
        var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
        if result == cur_limit:
            if PBPacker.check_required(data):
                if limit == -1:
                    return PB_ERR.NO_ERRORS
            else:
                return PB_ERR.REQUIRED_FIELDS
        elif limit == -1 && result > 0:
            return PB_ERR.PARSE_INCOMPLETE
        return result
    
class TRotation:
    func _init():
        var service
        
        var __vector_default: Array[float] = []
        __vector = PBField.new("vector", PB_DATA_TYPE.FLOAT, PB_RULE.REPEATED, 1, true, __vector_default)
        service = PBServiceField.new()
        service.field = __vector
        data[__vector.tag] = service
        
    var data = {}
    
    var __vector: PBField
    func get_vector() -> Array[float]:
        return __vector.value
    func clear_vector() -> void:
        data[1].state = PB_SERVICE_STATE.UNFILLED
        __vector.value.clear()
    func add_vector(value : float) -> void:
        __vector.value.append(value)
    
    func _to_string() -> String:
        return PBPacker.message_to_string(data)
        
    func to_bytes() -> PackedByteArray:
        return PBPacker.pack_message(data)
        
    func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
        var cur_limit = bytes.size()
        if limit != -1:
            cur_limit = limit
        var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
        if result == cur_limit:
            if PBPacker.check_required(data):
                if limit == -1:
                    return PB_ERR.NO_ERRORS
            else:
                return PB_ERR.REQUIRED_FIELDS
        elif limit == -1 && result > 0:
            return PB_ERR.PARSE_INCOMPLETE
        return result
    
class TPing:
    func _init():
        var service
        
        __timestamp = PBField.new("timestamp", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
        service = PBServiceField.new()
        service.field = __timestamp
        data[__timestamp.tag] = service
        
        __ping_id = PBField.new("ping_id", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
        service = PBServiceField.new()
        service.field = __ping_id
        data[__ping_id.tag] = service
        
    var data = {}
    
    var __timestamp: PBField
    func has_timestamp() -> bool:
        if __timestamp.value != null:
            return true
        return false
    func get_timestamp() -> int:
        return __timestamp.value
    func clear_timestamp() -> void:
        data[1].state = PB_SERVICE_STATE.UNFILLED
        __timestamp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
    func set_timestamp(value : int) -> void:
        __timestamp.value = value
    
    var __ping_id: PBField
    func has_ping_id() -> bool:
        if __ping_id.value != null:
            return true
        return false
    func get_ping_id() -> int:
        return __ping_id.value
    func clear_ping_id() -> void:
        data[2].state = PB_SERVICE_STATE.UNFILLED
        __ping_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
    func set_ping_id(value : int) -> void:
        __ping_id.value = value
    
    func _to_string() -> String:
        return PBPacker.message_to_string(data)
        
    func to_bytes() -> PackedByteArray:
        return PBPacker.pack_message(data)
        
    func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
        var cur_limit = bytes.size()
        if limit != -1:
            cur_limit = limit
        var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
        if result == cur_limit:
            if PBPacker.check_required(data):
                if limit == -1:
                    return PB_ERR.NO_ERRORS
            else:
                return PB_ERR.REQUIRED_FIELDS
        elif limit == -1 && result > 0:
            return PB_ERR.PARSE_INCOMPLETE
        return result
    
class TAnimation:
    func _init():
        var service
        
        __name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
        service = PBServiceField.new()
        service.field = __name
        data[__name.tag] = service
        
        __speed = PBField.new("speed", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
        service = PBServiceField.new()
        service.field = __speed
        data[__speed.tag] = service
        
        __playing = PBField.new("playing", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
        service = PBServiceField.new()
        service.field = __playing
        data[__playing.tag] = service
        
    var data = {}
    
    var __name: PBField
    func has_name() -> bool:
        if __name.value != null:
            return true
        return false
    func get_name() -> String:
        return __name.value
    func clear_name() -> void:
        data[1].state = PB_SERVICE_STATE.UNFILLED
        __name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
    func set_name(value : String) -> void:
        __name.value = value
    
    var __speed: PBField
    func has_speed() -> bool:
        if __speed.value != null:
            return true
        return false
    func get_speed() -> float:
        return __speed.value
    func clear_speed() -> void:
        data[2].state = PB_SERVICE_STATE.UNFILLED
        __speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
    func set_speed(value : float) -> void:
        __speed.value = value
    
    var __playing: PBField
    func has_playing() -> bool:
        if __playing.value != null:
            return true
        return false
    func get_playing() -> bool:
        return __playing.value
    func clear_playing() -> void:
        data[3].state = PB_SERVICE_STATE.UNFILLED
        __playing.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
    func set_playing(value : bool) -> void:
        __playing.value = value
    
    func _to_string() -> String:
        return PBPacker.message_to_string(data)
        
    func to_bytes() -> PackedByteArray:
        return PBPacker.pack_message(data)
        
    func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
        var cur_limit = bytes.size()
        if limit != -1:
            cur_limit = limit
        var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
        if result == cur_limit:
            if PBPacker.check_required(data):
                if limit == -1:
                    return PB_ERR.NO_ERRORS
            else:
                return PB_ERR.REQUIRED_FIELDS
        elif limit == -1 && result > 0:
            return PB_ERR.PARSE_INCOMPLETE
        return result
    
class TClientState:
    func _init():
        var service
        
        __world_hash = PBField.new("world_hash", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 0, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
        service = PBServiceField.new()
        service.field = __world_hash
        data[__world_hash.tag] = service
        
        __position = PBField.new("position", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
        service = PBServiceField.new()
        service.field = __position
        service.func_ref = Callable(self, "new_position")
        data[__position.tag] = service
        
        __velocity = PBField.new("velocity", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
        service = PBServiceField.new()
        service.field = __velocity
        service.func_ref = Callable(self, "new_velocity")
        data[__velocity.tag] = service
        
        __rotation = PBField.new("rotation", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
        service = PBServiceField.new()
        service.field = __rotation
        service.func_ref = Callable(self, "new_rotation")
        data[__rotation.tag] = service
        
        __animation = PBField.new("animation", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
        service = PBServiceField.new()
        service.field = __animation
        service.func_ref = Callable(self, "new_animation")
        data[__animation.tag] = service
        
        __visibility = PBField.new("visibility", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
        service = PBServiceField.new()
        service.field = __visibility
        service.func_ref = Callable(self, "new_visibility")
        data[__visibility.tag] = service
        
    var data = {}
    
    var __world_hash: PBField
    func has_world_hash() -> bool:
        if __world_hash.value != null:
            return true
        return false
    func get_world_hash() -> int:
        return __world_hash.value
    func clear_world_hash() -> void:
        data[0].state = PB_SERVICE_STATE.UNFILLED
        __world_hash.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
    func set_world_hash(value : int) -> void:
        __world_hash.value = value
    
    var __position: PBField
    func has_position() -> bool:
        if __position.value != null:
            return true
        return false
    func get_position() -> TPosition:
        return __position.value
    func clear_position() -> void:
        data[1].state = PB_SERVICE_STATE.UNFILLED
        __position.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
    func new_position() -> TPosition:
        __position.value = TPosition.new()
        return __position.value
    
    var __velocity: PBField
    func has_velocity() -> bool:
        if __velocity.value != null:
            return true
        return false
    func get_velocity() -> TVelocity:
        return __velocity.value
    func clear_velocity() -> void:
        data[2].state = PB_SERVICE_STATE.UNFILLED
        __velocity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
    func new_velocity() -> TVelocity:
        __velocity.value = TVelocity.new()
        return __velocity.value
    
    var __rotation: PBField
    func has_rotation() -> bool:
        if __rotation.value != null:
            return true
        return false
    func get_rotation() -> TRotation:
        return __rotation.value
    func clear_rotation() -> void:
        data[3].state = PB_SERVICE_STATE.UNFILLED
        __rotation.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
    func new_rotation() -> TRotation:
        __rotation.value = TRotation.new()
        return __rotation.value
    
    var __animation: PBField
    func has_animation() -> bool:
        if __animation.value != null:
            return true
        return false
    func get_animation() -> TAnimation:
        return __animation.value
    func clear_animation() -> void:
        data[4].state = PB_SERVICE_STATE.UNFILLED
        __animation.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
    func new_animation() -> TAnimation:
        __animation.value = TAnimation.new()
        return __animation.value
    
    var __visibility: PBField
    func has_visibility() -> bool:
        if __visibility.value != null:
            return true
        return false
    func get_visibility() -> TVisibility:
        return __visibility.value
    func clear_visibility() -> void:
        data[5].state = PB_SERVICE_STATE.UNFILLED
        __visibility.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
    func new_visibility() -> TVisibility:
        __visibility.value = TVisibility.new()
        return __visibility.value
    
    func _to_string() -> String:
        return PBPacker.message_to_string(data)
        
    func to_bytes() -> PackedByteArray:
        return PBPacker.pack_message(data)
        
    func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
        var cur_limit = bytes.size()
        if limit != -1:
            cur_limit = limit
        var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
        if result == cur_limit:
            if PBPacker.check_required(data):
                if limit == -1:
                    return PB_ERR.NO_ERRORS
            else:
                return PB_ERR.REQUIRED_FIELDS
        elif limit == -1 && result > 0:
            return PB_ERR.PARSE_INCOMPLETE
        return result
    
class TSignedClientState:
    func _init():
        var service
        
        __uid = PBField.new("uid", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
        service = PBServiceField.new()
        service.field = __uid
        data[__uid.tag] = service
        
        __state = PBField.new("state", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
        service = PBServiceField.new()
        service.field = __state
        service.func_ref = Callable(self, "new_state")
        data[__state.tag] = service
        
        __action = PBField.new("action", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
        service = PBServiceField.new()
        service.field = __action
        data[__action.tag] = service
        
    var data = {}
    
    var __uid: PBField
    func has_uid() -> bool:
        if __uid.value != null:
            return true
        return false
    func get_uid() -> int:
        return __uid.value
    func clear_uid() -> void:
        data[1].state = PB_SERVICE_STATE.UNFILLED
        __uid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
    func set_uid(value : int) -> void:
        __uid.value = value
    
    var __state: PBField
    func has_state() -> bool:
        if __state.value != null:
            return true
        return false
    func get_state() -> TClientState:
        return __state.value
    func clear_state() -> void:
        data[2].state = PB_SERVICE_STATE.UNFILLED
        __state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
    func new_state() -> TClientState:
        __state.value = TClientState.new()
        return __state.value
    
    var __action: PBField
    func has_action() -> bool:
        if __action.value != null:
            return true
        return false
    func get_action():
        return __action.value
    func clear_action() -> void:
        data[3].state = PB_SERVICE_STATE.UNFILLED
        __action.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
    func set_action(value) -> void:
        __action.value = value
    
    func _to_string() -> String:
        return PBPacker.message_to_string(data)
        
    func to_bytes() -> PackedByteArray:
        return PBPacker.pack_message(data)
        
    func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
        var cur_limit = bytes.size()
        if limit != -1:
            cur_limit = limit
        var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
        if result == cur_limit:
            if PBPacker.check_required(data):
                if limit == -1:
                    return PB_ERR.NO_ERRORS
            else:
                return PB_ERR.REQUIRED_FIELDS
        elif limit == -1 && result > 0:
            return PB_ERR.PARSE_INCOMPLETE
        return result
    
class TSignedClientMessage:
    func _init():
        var service
        
        __uid = PBField.new("uid", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
        service = PBServiceField.new()
        service.field = __uid
        data[__uid.tag] = service
        
        __msg = PBField.new("msg", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
        service = PBServiceField.new()
        service.field = __msg
        data[__msg.tag] = service
        
    var data = {}
    
    var __uid: PBField
    func has_uid() -> bool:
        if __uid.value != null:
            return true
        return false
    func get_uid() -> int:
        return __uid.value
    func clear_uid() -> void:
        data[1].state = PB_SERVICE_STATE.UNFILLED
        __uid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
    func set_uid(value : int) -> void:
        __uid.value = value
    
    var __msg: PBField
    func has_msg() -> bool:
        if __msg.value != null:
            return true
        return false
    func get_msg() -> String:
        return __msg.value
    func clear_msg() -> void:
        data[2].state = PB_SERVICE_STATE.UNFILLED
        __msg.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
    func set_msg(value : String) -> void:
        __msg.value = value
    
    func _to_string() -> String:
        return PBPacker.message_to_string(data)
        
    func to_bytes() -> PackedByteArray:
        return PBPacker.pack_message(data)
        
    func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
        var cur_limit = bytes.size()
        if limit != -1:
            cur_limit = limit
        var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
        if result == cur_limit:
            if PBPacker.check_required(data):
                if limit == -1:
                    return PB_ERR.NO_ERRORS
            else:
                return PB_ERR.REQUIRED_FIELDS
        elif limit == -1 && result > 0:
            return PB_ERR.PARSE_INCOMPLETE
        return result
    
class TVisibility:
    func _init():
        var service
        
        var __shown_default: Array[String] = []
        __shown = PBField.new("shown", PB_DATA_TYPE.STRING, PB_RULE.REPEATED, 1, true, __shown_default)
        service = PBServiceField.new()
        service.field = __shown
        data[__shown.tag] = service
        
        var __hidden_default: Array[String] = []
        __hidden = PBField.new("hidden", PB_DATA_TYPE.STRING, PB_RULE.REPEATED, 2, true, __hidden_default)
        service = PBServiceField.new()
        service.field = __hidden
        data[__hidden.tag] = service
        
    var data = {}
    
    var __shown: PBField
    func get_shown() -> Array[String]:
        return __shown.value
    func clear_shown() -> void:
        data[1].state = PB_SERVICE_STATE.UNFILLED
        __shown.value.clear()
    func add_shown(value : String) -> void:
        __shown.value.append(value)
    
    var __hidden: PBField
    func get_hidden() -> Array[String]:
        return __hidden.value
    func clear_hidden() -> void:
        data[2].state = PB_SERVICE_STATE.UNFILLED
        __hidden.value.clear()
    func add_hidden(value : String) -> void:
        __hidden.value.append(value)
    
    func _to_string() -> String:
        return PBPacker.message_to_string(data)
        
    func to_bytes() -> PackedByteArray:
        return PBPacker.pack_message(data)
        
    func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
        var cur_limit = bytes.size()
        if limit != -1:
            cur_limit = limit
        var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
        if result == cur_limit:
            if PBPacker.check_required(data):
                if limit == -1:
                    return PB_ERR.NO_ERRORS
            else:
                return PB_ERR.REQUIRED_FIELDS
        elif limit == -1 && result > 0:
            return PB_ERR.PARSE_INCOMPLETE
        return result
    
class TClientData:
    func _init():
        var service
        
        __chat_message = PBField.new("chat_message", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
        service = PBServiceField.new()
        service.field = __chat_message
        service.func_ref = Callable(self, "new_chat_message")
        data[__chat_message.tag] = service
        
        __ping = PBField.new("ping", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
        service = PBServiceField.new()
        service.field = __ping
        service.func_ref = Callable(self, "new_ping")
        data[__ping.tag] = service
        
        __signed_state = PBField.new("signed_state", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
        service = PBServiceField.new()
        service.field = __signed_state
        service.func_ref = Callable(self, "new_signed_state")
        data[__signed_state.tag] = service
        
        __sync_request = PBField.new("sync_request", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
        service = PBServiceField.new()
        service.field = __sync_request
        data[__sync_request.tag] = service
        
    var data = {}
    
    var __chat_message: PBField
    func has_chat_message() -> bool:
        if __chat_message.value != null:
            return true
        return false
    func get_chat_message() -> TSignedClientMessage:
        return __chat_message.value
    func clear_chat_message() -> void:
        data[1].state = PB_SERVICE_STATE.UNFILLED
        __chat_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
    func new_chat_message() -> TSignedClientMessage:
        data[1].state = PB_SERVICE_STATE.FILLED
        __ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[2].state = PB_SERVICE_STATE.UNFILLED
        __signed_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[3].state = PB_SERVICE_STATE.UNFILLED
        __sync_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
        data[4].state = PB_SERVICE_STATE.UNFILLED
        __chat_message.value = TSignedClientMessage.new()
        return __chat_message.value
    
    var __ping: PBField
    func has_ping() -> bool:
        if __ping.value != null:
            return true
        return false
    func get_ping() -> TPing:
        return __ping.value
    func clear_ping() -> void:
        data[2].state = PB_SERVICE_STATE.UNFILLED
        __ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
    func new_ping() -> TPing:
        __chat_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[1].state = PB_SERVICE_STATE.UNFILLED
        data[2].state = PB_SERVICE_STATE.FILLED
        __signed_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[3].state = PB_SERVICE_STATE.UNFILLED
        __sync_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
        data[4].state = PB_SERVICE_STATE.UNFILLED
        __ping.value = TPing.new()
        return __ping.value
    
    var __signed_state: PBField
    func has_signed_state() -> bool:
        if __signed_state.value != null:
            return true
        return false
    func get_signed_state() -> TSignedClientState:
        return __signed_state.value
    func clear_signed_state() -> void:
        data[3].state = PB_SERVICE_STATE.UNFILLED
        __signed_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
    func new_signed_state() -> TSignedClientState:
        __chat_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[1].state = PB_SERVICE_STATE.UNFILLED
        __ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[2].state = PB_SERVICE_STATE.UNFILLED
        data[3].state = PB_SERVICE_STATE.FILLED
        __sync_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
        data[4].state = PB_SERVICE_STATE.UNFILLED
        __signed_state.value = TSignedClientState.new()
        return __signed_state.value
    
    var __sync_request: PBField
    func has_sync_request() -> bool:
        if __sync_request.value != null:
            return true
        return false
    func get_sync_request() -> bool:
        return __sync_request.value
    func clear_sync_request() -> void:
        data[4].state = PB_SERVICE_STATE.UNFILLED
        __sync_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
    func set_sync_request(value : bool) -> void:
        __chat_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[1].state = PB_SERVICE_STATE.UNFILLED
        __ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[2].state = PB_SERVICE_STATE.UNFILLED
        __signed_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[3].state = PB_SERVICE_STATE.UNFILLED
        data[4].state = PB_SERVICE_STATE.FILLED
        __sync_request.value = value
    
    func _to_string() -> String:
        return PBPacker.message_to_string(data)
        
    func to_bytes() -> PackedByteArray:
        return PBPacker.pack_message(data)
        
    func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
        var cur_limit = bytes.size()
        if limit != -1:
            cur_limit = limit
        var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
        if result == cur_limit:
            if PBPacker.check_required(data):
                if limit == -1:
                    return PB_ERR.NO_ERRORS
            else:
                return PB_ERR.REQUIRED_FIELDS
        elif limit == -1 && result > 0:
            return PB_ERR.PARSE_INCOMPLETE
        return result
    
class TPlayersState:
    func _init():
        var service
        
        var __signed_state_default: Array[TSignedClientState] = []
        __signed_state = PBField.new("signed_state", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __signed_state_default)
        service = PBServiceField.new()
        service.field = __signed_state
        service.func_ref = Callable(self, "add_signed_state")
        data[__signed_state.tag] = service
        
        __your_uid = PBField.new("your_uid", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 0, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
        service = PBServiceField.new()
        service.field = __your_uid
        data[__your_uid.tag] = service
        
    var data = {}
    
    var __signed_state: PBField
    func get_signed_state() -> Array[TSignedClientState]:
        return __signed_state.value
    func clear_signed_state() -> void:
        data[1].state = PB_SERVICE_STATE.UNFILLED
        __signed_state.value.clear()
    func add_signed_state() -> TSignedClientState:
        var element = TSignedClientState.new()
        __signed_state.value.append(element)
        return element
    
    var __your_uid: PBField
    func has_your_uid() -> bool:
        if __your_uid.value != null:
            return true
        return false
    func get_your_uid() -> int:
        return __your_uid.value
    func clear_your_uid() -> void:
        data[0].state = PB_SERVICE_STATE.UNFILLED
        __your_uid.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
    func set_your_uid(value : int) -> void:
        __your_uid.value = value
    
    func _to_string() -> String:
        return PBPacker.message_to_string(data)
        
    func to_bytes() -> PackedByteArray:
        return PBPacker.pack_message(data)
        
    func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
        var cur_limit = bytes.size()
        if limit != -1:
            cur_limit = limit
        var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
        if result == cur_limit:
            if PBPacker.check_required(data):
                if limit == -1:
                    return PB_ERR.NO_ERRORS
            else:
                return PB_ERR.REQUIRED_FIELDS
        elif limit == -1 && result > 0:
            return PB_ERR.PARSE_INCOMPLETE
        return result
    
class TServerData:
    func _init():
        var service
        
        __players = PBField.new("players", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
        service = PBServiceField.new()
        service.field = __players
        service.func_ref = Callable(self, "new_players")
        data[__players.tag] = service
        
        __chat_message = PBField.new("chat_message", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
        service = PBServiceField.new()
        service.field = __chat_message
        service.func_ref = Callable(self, "new_chat_message")
        data[__chat_message.tag] = service
        
        __state_request = PBField.new("state_request", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
        service = PBServiceField.new()
        service.field = __state_request
        data[__state_request.tag] = service
        
        __ping = PBField.new("ping", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
        service = PBServiceField.new()
        service.field = __ping
        service.func_ref = Callable(self, "new_ping")
        data[__ping.tag] = service
        
    var data = {}
    
    var __players: PBField
    func has_players() -> bool:
        if __players.value != null:
            return true
        return false
    func get_players() -> TPlayersState:
        return __players.value
    func clear_players() -> void:
        data[1].state = PB_SERVICE_STATE.UNFILLED
        __players.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
    func new_players() -> TPlayersState:
        data[1].state = PB_SERVICE_STATE.FILLED
        __chat_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[2].state = PB_SERVICE_STATE.UNFILLED
        __state_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
        data[3].state = PB_SERVICE_STATE.UNFILLED
        __ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[4].state = PB_SERVICE_STATE.UNFILLED
        __players.value = TPlayersState.new()
        return __players.value
    
    var __chat_message: PBField
    func has_chat_message() -> bool:
        if __chat_message.value != null:
            return true
        return false
    func get_chat_message() -> TSignedClientMessage:
        return __chat_message.value
    func clear_chat_message() -> void:
        data[2].state = PB_SERVICE_STATE.UNFILLED
        __chat_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
    func new_chat_message() -> TSignedClientMessage:
        __players.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[1].state = PB_SERVICE_STATE.UNFILLED
        data[2].state = PB_SERVICE_STATE.FILLED
        __state_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
        data[3].state = PB_SERVICE_STATE.UNFILLED
        __ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[4].state = PB_SERVICE_STATE.UNFILLED
        __chat_message.value = TSignedClientMessage.new()
        return __chat_message.value
    
    var __state_request: PBField
    func has_state_request() -> bool:
        if __state_request.value != null:
            return true
        return false
    func get_state_request() -> bool:
        return __state_request.value
    func clear_state_request() -> void:
        data[3].state = PB_SERVICE_STATE.UNFILLED
        __state_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
    func set_state_request(value : bool) -> void:
        __players.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[1].state = PB_SERVICE_STATE.UNFILLED
        __chat_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[2].state = PB_SERVICE_STATE.UNFILLED
        data[3].state = PB_SERVICE_STATE.FILLED
        __ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[4].state = PB_SERVICE_STATE.UNFILLED
        __state_request.value = value
    
    var __ping: PBField
    func has_ping() -> bool:
        if __ping.value != null:
            return true
        return false
    func get_ping() -> TPing:
        return __ping.value
    func clear_ping() -> void:
        data[4].state = PB_SERVICE_STATE.UNFILLED
        __ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
    func new_ping() -> TPing:
        __players.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[1].state = PB_SERVICE_STATE.UNFILLED
        __chat_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
        data[2].state = PB_SERVICE_STATE.UNFILLED
        __state_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
        data[3].state = PB_SERVICE_STATE.UNFILLED
        data[4].state = PB_SERVICE_STATE.FILLED
        __ping.value = TPing.new()
        return __ping.value
    
    func _to_string() -> String:
        return PBPacker.message_to_string(data)
        
    func to_bytes() -> PackedByteArray:
        return PBPacker.pack_message(data)
        
    func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
        var cur_limit = bytes.size()
        if limit != -1:
            cur_limit = limit
        var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
        if result == cur_limit:
            if PBPacker.check_required(data):
                if limit == -1:
                    return PB_ERR.NO_ERRORS
            else:
                return PB_ERR.REQUIRED_FIELDS
        elif limit == -1 && result > 0:
            return PB_ERR.PARSE_INCOMPLETE
        return result
    
################ USER DATA END #################
