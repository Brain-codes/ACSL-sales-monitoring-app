# Username Authentication - Quick Deployment Checklist

## 📋 Pre-Deployment Verification

### Files Created ✅

- [x] `supabase/functions/login-with-credentials/index.ts`
- [x] `supabase/functions/login-with-credentials/API_DOCUMENTATION.md`
- [x] `supabase_codes/sql_queries/add-username-support.sql`
- [x] `REACT_LOGIN_INTEGRATION_GUIDE.md`
- [x] `FLUTTER_LOGIN_UPDATE_GUIDE.md`
- [x] `USERNAME_MIGRATION_SUMMARY.md`

### Files Updated ✅

- [x] `supabase/functions/external-sync/index.ts` (username generation)
- [x] `supabase_codes/edge_functions/external-sync/index.ts` (synced)
- [x] `supabase_codes/edge_functions/login-with-credentials/` (synced)

### Files Pending ⏳

- [ ] `supabase/functions/external-csv-sync/index.ts`
- [ ] `supabase/functions/manage-credentials/read-operations.ts`
- [ ] `supabase/functions/manage-credentials/update-operations.ts`

---

## 🚀 Deployment Steps

### Step 1: Database Migration

```bash
# 1. Open Supabase Dashboard
# 2. Navigate to SQL Editor
# 3. Open file: supabase_codes/sql_queries/add-username-support.sql
# 4. Copy all contents
# 5. Paste into SQL Editor
# 6. Click "Run"
```

**Validation Queries:**

```sql
-- Check columns added
SELECT column_name FROM information_schema.columns
WHERE table_name = 'profiles' AND column_name = 'username';

-- Count users by type
SELECT
  COUNT(*) FILTER (WHERE username IS NOT NULL) as username_users,
  COUNT(*) FILTER (WHERE username IS NULL) as email_users
FROM profiles;
```

**Expected Result:**

- `username` column exists in `profiles`
- `username` column exists in `credentials`
- Index created on `profiles.username`
- Existing dummy email users migrated

---

### Step 2: Deploy Edge Functions

#### Deploy login-with-credentials

```bash
cd supabase/functions
supabase functions deploy login-with-credentials
```

**Test:**

```bash
curl -X POST \
  https://YOUR_PROJECT.supabase.co/functions/v1/login-with-credentials \
  -H 'Content-Type: application/json' \
  -d '{
    "identifier": "test_username",
    "password": "TestPassword123"
  }'
```

---

#### Deploy updated external-sync

```bash
supabase functions deploy external-sync
```

**Test:**

```bash
curl -X POST \
  https://YOUR_PROJECT.supabase.co/functions/v1/external-sync \
  -H 'Content-Type: application/json' \
  -d '{
    "token": "YOUR_TOKEN",
    "secret_key": "YOUR_SECRET",
    "application_name": "Test App",
    "organization_data": {
      "partner_id": "TEST123",
      "partner_name": "Test Organization"
    }
  }'
```

**Expected Response:**

```json
{
  "success": true,
  "data": {
    "user": {
      "username": "test_organization_test123",
      "email": undefined,
      "password": "GeneratedPassword123",
      "login_identifier": "test_organization_test123"
    }
  }
}
```

---

### Step 3: Update Remaining Functions

#### Update external-csv-sync

1. Copy username generation logic from `external-sync`
2. Update `createUserForOrganization()` calls
3. Update `saveCredentials()` calls
4. Deploy: `supabase functions deploy external-csv-sync`

#### Update manage-credentials

1. Update GET endpoints to show username
2. Update password reset logic
3. Update API_DOCUMENTATION.md
4. Deploy: `supabase functions deploy manage-credentials`

---

## 🧪 Testing Protocol

### Test 1: Username Login

```bash
# Create test user with username
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/external-sync \
  -H 'Content-Type: application/json' \
  -d '{
    "token": "TOKEN",
    "secret_key": "SECRET",
    "application_name": "App",
    "organization_data": {
      "partner_id": "TEST001",
      "partner_name": "Test Partner",
      "email": "invalid"
    }
  }'

# Login with generated username
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/login-with-credentials \
  -H 'Content-Type: application/json' \
  -d '{
    "identifier": "test_partner_test001",
    "password": "PASSWORD_FROM_SYNC_RESPONSE"
  }'
```

**Expected:**

- ✅ Username generated: `test_partner_test001`
- ✅ Internal email created: `test_partner_test001@internal.acsl.local`
- ✅ Login successful with username
- ✅ Response shows username, NOT internal email

---

### Test 2: Email Login (Backward Compatibility)

```bash
# Create user with valid email
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/external-sync \
  -H 'Content-Type: application/json' \
  -d '{
    "token": "TOKEN",
    "secret_key": "SECRET",
    "application_name": "App",
    "organization_data": {
      "partner_id": "TEST002",
      "partner_name": "Email Partner",
      "email": "valid@email.com"
    }
  }'

# Login with email
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/login-with-credentials \
  -H 'Content-Type: application/json' \
  -d '{
    "identifier": "valid@email.com",
    "password": "PASSWORD_FROM_SYNC_RESPONSE"
  }'
```

**Expected:**

- ✅ Email used as-is: `valid@email.com`
- ✅ No username generated
- ✅ Login successful with email
- ✅ Response shows email

---

### Test 3: Error Cases

```bash
# Invalid username
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/login-with-credentials \
  -H 'Content-Type: application/json' \
  -d '{"identifier": "nonexistent_user", "password": "wrong"}'

# Invalid password
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/login-with-credentials \
  -H 'Content-Type: application/json' \
  -d '{"identifier": "test_partner_test001", "password": "wrong"}'

# Missing fields
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/login-with-credentials \
  -H 'Content-Type: application/json' \
  -d '{"identifier": "test_user"}'
```

**Expected:**

- ✅ Generic error: "Invalid username or password"
- ✅ No hint about which identifier exists
- ✅ 401 status code

---

## 📱 Frontend Integration

### React (External Developer)

1. Share `REACT_LOGIN_INTEGRATION_GUIDE.md`
2. Provide Supabase URL and Anon Key
3. Verify environment variables set
4. Test login component works

**Verification:**

```typescript
// Test in browser console
fetch("https://YOUR_PROJECT.supabase.co/functions/v1/login-with-credentials", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    identifier: "test_username",
    password: "TestPassword123",
  }),
})
  .then((r) => r.json())
  .then(console.log);
```

---

### Flutter (Main App)

1. Share `FLUTTER_LOGIN_UPDATE_GUIDE.md` with Flutter team
2. Update `LoginController`
3. Update `login_screen.dart` UI
4. Add `username` field to `ProfileModel`
5. Test with both username and email

**Verification Checklist:**

- [ ] Label shows "Username or Email"
- [ ] Input accepts both formats
- [ ] Login works with username
- [ ] Login works with email
- [ ] Error messages are appropriate
- [ ] Session persists correctly

---

## 🔍 Database Verification

### Check Migration Success

```sql
-- Verify schema changes
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name IN ('profiles', 'credentials')
  AND column_name = 'username';

-- Check index
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'profiles'
  AND indexname = 'idx_profiles_username';

-- Sample data
SELECT
  id,
  email,
  username,
  CASE
    WHEN username IS NOT NULL THEN 'username-based'
    ELSE 'email-based'
  END as user_type
FROM profiles
LIMIT 10;
```

---

## 📊 Monitoring

### Post-Deployment Checks

#### Day 1

- [ ] Monitor edge function logs for errors
- [ ] Check login success rate
- [ ] Verify no internal emails exposed in responses
- [ ] Monitor database for username uniqueness violations

#### Week 1

- [ ] Review user feedback
- [ ] Check error rates
- [ ] Verify session management working
- [ ] Monitor password reset flows

#### Month 1

- [ ] Analyze username vs email login ratio
- [ ] Review performance metrics
- [ ] Check for any edge cases
- [ ] Plan for additional features (2FA, etc.)

---

## 🚨 Rollback Procedure

### If Issues Occur

#### Database Rollback

```sql
-- Remove username columns
ALTER TABLE profiles DROP COLUMN IF EXISTS username;
ALTER TABLE credentials DROP COLUMN IF EXISTS username;
DROP INDEX IF EXISTS idx_profiles_username;
```

#### Edge Function Rollback

```bash
# Redeploy original functions from backup
cd supabase_codes/edge_functions
cp -r external-sync-backup/* ../functions/external-sync/
supabase functions deploy external-sync

# Remove login-with-credentials
supabase functions delete login-with-credentials
```

#### Frontend Rollback

- Revert login screen changes
- Change back to email-only input
- Redeploy previous version

---

## ✅ Sign-Off Checklist

### Before Going Live

- [ ] SQL migration tested in staging
- [ ] All edge functions deployed and tested
- [ ] Username generation verified
- [ ] Internal emails NOT exposed
- [ ] Both login types work
- [ ] Error handling correct
- [ ] Frontend teams notified
- [ ] Documentation shared
- [ ] Rollback plan reviewed
- [ ] Monitoring configured

### After Deployment

- [ ] Verify live login with username
- [ ] Verify live login with email
- [ ] Check production logs
- [ ] Confirm no errors reported
- [ ] User feedback positive
- [ ] All teams notified of completion

---

## 📞 Emergency Contacts

**Backend Issues:**

- Edge function errors: Check Supabase Dashboard → Functions → Logs
- Database errors: Check Supabase Dashboard → Database → Logs

**Frontend Issues:**

- React: External developer (provide contact)
- Flutter: Internal team (provide contact)

**Escalation:**

- Critical bugs: Rollback immediately
- Minor issues: Document and schedule fix

---

## 📝 Notes

### Key Points to Remember

1. Internal emails are NEVER shown to users
2. Username format: `partner_name_partnerId`
3. Both login methods supported simultaneously
4. Existing users unaffected
5. New users get usernames by default

### Common Questions

**Q: What if username already exists?**  
A: Database unique constraint prevents duplicates. Error returned.

**Q: Can users change their username?**  
A: Not currently implemented. Future feature.

**Q: Can email-based users add a username?**  
A: Not currently. Migration possible in future.

**Q: What happens to internal emails if we delete username?**  
A: User becomes inaccessible. Must recreate user.

---

**Deployment Owner:** ******\_******  
**Date Deployed:** ******\_******  
**Status:** [ ] Not Started [ ] In Progress [ ] Complete

---

## 📚 Related Documentation

- `USERNAME_MIGRATION_SUMMARY.md` - Complete migration overview
- `REACT_LOGIN_INTEGRATION_GUIDE.md` - React developer guide
- `FLUTTER_LOGIN_UPDATE_GUIDE.md` - Flutter developer guide
- `supabase/functions/login-with-credentials/API_DOCUMENTATION.md` - API reference
- `supabase_codes/sql_queries/add-username-support.sql` - Database migration

---

**Version:** 1.0  
**Last Updated:** 2025-01-XX  
**Next Review:** After successful deployment
