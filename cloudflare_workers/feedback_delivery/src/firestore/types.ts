/**
 * Cloud Firestore REST API Types
 */

export interface FirestoreValue {
  stringValue?: string;
  integerValue?: string | number;
  booleanValue?: boolean;
  timestampValue?: string;
  nullValue?: null;
  mapValue?: { fields: Record<string, FirestoreValue> };
}

export interface FirestoreDocument {
  name: string;
  fields?: Record<string, FirestoreValue>;
  createTime?: string;
  updateTime?: string;
}

export interface RunQueryResponseItem {
  document?: FirestoreDocument;
  readTime: string;
}

export interface FirestoreCommitWrite {
  update?: {
    name: string;
    fields: Record<string, FirestoreValue>;
  };
  updateMask?: {
    fieldPaths: string[];
  };
  currentDocument?: {
    exists?: boolean;
    updateTime?: string;
  };
}

export interface FirestoreCommitRequest {
  writes: FirestoreCommitWrite[];
  transaction?: string;
}

export interface FirestoreCommitResponse {
  commitTime: string;
  writeResults?: Array<{
    updateTime?: string;
  }>;
}
