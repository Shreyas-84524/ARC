import urllib.request
import json
import ssl

API_KEY = 'AIzaSyCTp6kyYEFN_yBX-cnRAR45E66dGk4UHVo'
PROJECT_ID = 'arc-productivity-shreyas'

USERS = [
    ('Shreyas', 'shreyas@arc.app', 'u0xSvSMCmOYGrJK2GPfKYmpuUVl1'),
    ('Aman', 'aman@arc.app', 'h50zGVpLVfVwwfpl4C6naIud8y23'),
    ('Rohit', 'rohit@arc.app', 'b2xc1LvAhvaEvFZg1Bbq0aaXUUf1'),
    ('Sachi', 'sachi@arc.app', 'ncFYWudsifXfLza208CI16Lk3k23'),
    ('Yash', 'yash@arc.app', 'cJZudeqQonYFAp3SnzcqFov6ysQ2'),
]

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

def authenticate(email, password='123456'):
    url = f'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}'
    payload = json.dumps({
        'email': email,
        'password': password,
        'returnSecureToken': True
    }).encode('utf-8')
    
    req = urllib.request.Request(url, data=payload, headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, context=ctx) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            return data.get('idToken'), data.get('localId')
    except Exception as e:
        print(f"Auth error for {email}: {e}")
        return None, None

def query_firestore_collection(id_token, collection_path):
    total_docs = 0
    page_token = None
    
    while True:
        url = f'https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/{collection_path}?pageSize=300'
        if page_token:
            url += f'&pageToken={page_token}'
            
        headers = {}
        if id_token:
            headers['Authorization'] = f'Bearer {id_token}'
            
        req = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(req, context=ctx) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                docs = data.get('documents', [])
                total_docs += len(docs)
                page_token = data.get('nextPageToken')
                if not page_token:
                    return True, total_docs, 200
        except urllib.error.HTTPError as e:
            return False, 0, e.code
        except Exception as e:
            return False, 0, 500

def run_step5_audit():
    print("==========================================================")
    print("PROJECT ARC — STEP 5 FIREBASE MULTI-USER AUDIT")
    print("==========================================================")
    
    tokens = {}
    
    # 1. Authenticate all 5 users
    print("\n--- 1. AUTHENTICATION & UID VERIFICATION ---")
    for username, email, expected_uid in USERS:
        token, uid = authenticate(email)
        tokens[username] = (token, uid)
        status = "PASS" if uid == expected_uid else "FAIL"
        print(f"User: {username:7s} | Email: {email:16s} | Expected: {expected_uid} | Returned: {uid} | Status: {status}")
        
    # 2. Shreyas Data Verification (Read-Only)
    print("\n--- 2. SHREYAS DATA ACCESSIBILITY (READ-ONLY) ---")
    shreyas_token, shreyas_uid = tokens['Shreyas']
    subcollections = ['tasks', 'habits', 'habitEntries', 'transactions', 'budgets', 'monthlySummaries']
    
    total_shreyas_docs = 0
    for sub in subcollections:
        ok, count, status_code = query_firestore_collection(shreyas_token, f'users/{shreyas_uid}/{sub}')
        total_shreyas_docs += count
        print(f"  Collection: users/{shreyas_uid}/{sub:16s} | Accessible: {ok} | Document Count: {count}")
    
    # Profile doc
    ok, count, _ = query_firestore_collection(shreyas_token, f'users/{shreyas_uid}/settings')
    total_shreyas_docs += count
    print(f"  Collection: users/{shreyas_uid}/settings         | Accessible: {ok} | Document Count: {count}")
    print(f"Total Shreyas Migrated Document Count: {total_shreyas_docs} / 230 expected")
    
    # 3. Cross-User Security Rules Isolation Test
    print("\n--- 3. CROSS-USER SECURITY RULES ENFORCEMENT ---")
    for username, (token, uid) in tokens.items():
        if username == 'Shreyas':
            continue
        # Attempt to access Shreyas's tasks using another user's token
        ok, count, status_code = query_firestore_collection(token, f'users/{shreyas_uid}/tasks')
        denied_properly = (status_code == 403)
        print(f"User: {username:7s} attempting to read Shreyas path -> Allowed: {ok} | HTTP Status: {status_code} | Denied: {denied_properly}")
        
    # 4. Secondary User Namespace Count Verification
    print("\n--- 4. SECONDARY USER NAMESPACE COUNTS ---")
    for username, (token, uid) in tokens.items():
        if username == 'Shreyas':
            continue
        user_total = 0
        for sub in subcollections:
            ok, count, _ = query_firestore_collection(token, f'users/{uid}/{sub}')
            user_total += count
        print(f"User: {username:7s} (UID: {uid}) | Namespace Document Count: {user_total} (Expected 0)")

    # 5. Legacy Root Collection Verification
    print("\n--- 5. LEGACY ROOT BACKUP DATA VERIFICATION ---")
    root_collections = ['tasks', 'habits', 'habitEntries', 'transactions', 'budgets', 'monthlySummaries', 'settings']
    root_total = 0
    for root_col in root_collections:
        ok, count, _ = query_firestore_collection(shreyas_token, root_col)
        root_total += count
        print(f"Root Collection: /{root_col:20s} | Document Count: {count}")
    print(f"Total Root Legacy Document Count: {root_total} / 230 expected")

if __name__ == '__main__':
    run_step5_audit()
