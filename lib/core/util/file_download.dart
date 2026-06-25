// Saves bytes as a file named [filename] (with MIME [mimeType]).
//
// On web this triggers a browser download via a Blob + anchor (returns null);
// on native platforms it writes to the downloads/documents directory and
// returns the saved path. The bytes are fetched through the authenticated
// ApiClient by the caller, so no object-store URL is ever exposed to the client
// (the storage endpoint is internal-only).
export 'file_download_io.dart'
    if (dart.library.js_interop) 'file_download_web.dart';
