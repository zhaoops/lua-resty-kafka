-- LZ4 Frame compression via LuaJIT FFI
-- Kafka 要求 LZ4F blockIndependent 模式 (KIP-57)
local ffi = require "ffi"

ffi.cdef[[
typedef enum { LZ4F_default=0, LZ4F_max64KB=4, LZ4F_max256KB=5, LZ4F_max1MB=6, LZ4F_max4MB=7 } LZ4F_blockSizeID_t;
typedef enum { LZ4F_blockLinked=0, LZ4F_blockIndependent=1 } LZ4F_blockMode_t;
typedef enum { LZ4F_noContentChecksum=0, LZ4F_contentChecksumEnabled=1 } LZ4F_contentChecksum_t;
typedef enum { LZ4F_noBlockChecksum=0, LZ4F_blockChecksumEnabled=1 } LZ4F_blockChecksum_t;
typedef enum { LZ4F_frame=0, LZ4F_skippableFrame=1 } LZ4F_frameType_t;

typedef struct {
    LZ4F_blockSizeID_t     blockSizeID;
    LZ4F_blockMode_t       blockMode;
    LZ4F_contentChecksum_t contentChecksumFlag;
    LZ4F_frameType_t       frameType;
    unsigned long long     contentSize;
    unsigned               dictID;
    LZ4F_blockChecksum_t   blockChecksumFlag;
} LZ4F_frameInfo_t;

typedef struct {
    LZ4F_frameInfo_t frameInfo;
    int              compressionLevel;
    unsigned         autoFlush;
    unsigned         favorDecSpeed;
    unsigned         reserved[3];
} LZ4F_preferences_t;

size_t LZ4F_compressFrameBound(size_t srcSize, const LZ4F_preferences_t* prefsPtr);
size_t LZ4F_compressFrame(void* dst, size_t dstCapacity,
                           const void* src, size_t srcSize,
                           const LZ4F_preferences_t* prefsPtr);
unsigned LZ4F_isError(size_t code);
const char* LZ4F_getErrorName(size_t code);
]]

local lib = ffi.load("lz4")

-- Kafka 要求: blockIndependent, 无 contentChecksum
local prefs = ffi.new("LZ4F_preferences_t")
prefs.frameInfo.blockSizeID = ffi.C.LZ4F_max256KB
prefs.frameInfo.blockMode = ffi.C.LZ4F_blockIndependent
prefs.frameInfo.contentChecksumFlag = ffi.C.LZ4F_noContentChecksum
prefs.compressionLevel = 1  -- fast

local _M = {}

function _M.compress(data)
    local src_size = #data
    local bound = lib.LZ4F_compressFrameBound(src_size, prefs)
    local dst = ffi.new("uint8_t[?]", bound)

    local compressed_size = lib.LZ4F_compressFrame(
        dst, bound, data, src_size, prefs)

    if lib.LZ4F_isError(compressed_size) ~= 0 then
        return nil, ffi.string(lib.LZ4F_getErrorName(compressed_size))
    end

    return ffi.string(dst, compressed_size)
end

return _M
