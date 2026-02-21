import firebase_admin
from firebase_admin import credentials, firestore
import csv

# 1. Firebase Connect
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# USER ID (Jiske account me dalna hai)
USER_UID = "YAHAN_APNA_USER_UID_DALO" 

# 2. CSV File Padho
with open('products.csv', 'r') as file:
    reader = csv.DictReader(file)
    
    batch = db.batch()
    count = 0

    for row in reader:
        # Document ID = Barcode
        doc_ref = db.collection('users').document(USER_UID).collection('products').document(row['barcode'])
        
        # Data Prepare
        data = {
            'name': row['name'],
            'barcode': row['barcode'],
            'price': float(row['price']),
            'gst': float(row['gst']),
            'stock': int(row['stock']),
            'weight': float(row['weight']), # Security Weight
            'imageUrl': row['image_url'] if row['image_url'] else None,
            'createdAt': firestore.SERVER_TIMESTAMP
        }
        
        batch.set(doc_ref, data)
        count += 1

        # Firebase Batch limit is 500
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
            print(f"{count} Products Uploaded...")

    batch.commit()
    print("✅ SUB PRODUCT UPLOAD HO GAYE!")