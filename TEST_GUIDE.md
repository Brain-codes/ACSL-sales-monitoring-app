# Comprehensive Test Guide - ACSL Sales Monitoring App

## Overview

This test guide covers all major features, flows, and edge cases for the **ACSL Sales Monitoring Application** - a Flutter-based sales management system with offline-first capabilities supporting both Admin and Agent roles.

## Test Environment Setup

- **Test Device**: Android/iOS device or emulator
- **Network Conditions**: Test both online and offline scenarios
- **User Accounts**: Admin and Agent test accounts required
- **Test Data**: Sample stove IDs, organization data, and test images

---

## 🔐 Authentication & User Management

### A1. User Registration

**Test Case Name**: New User Registration Process  
**Preconditions**: App is installed, no existing account  
**Steps to Reproduce**:

1. Open the app
2. Navigate through onboarding screens
3. Tap "Sign Up" on login screen
4. Enter valid full name, email, and password
5. Confirm password matches
6. Accept terms and conditions
7. Tap "Register"

**Expected Result**:

- User receives confirmation email
- Success toast appears
- Redirected to login screen
- [ ] Pass [ ] Fail

### A2. Valid Login - Admin

**Test Case Name**: Admin login with valid credentials  
**Preconditions**: Admin account exists and is confirmed  
**Steps to Reproduce**:

1. Open login screen
2. Enter valid admin email
3. Enter correct password
4. Tap "Login"

**Expected Result**:

- Loading indicator appears
- Success toast shows "Login successful!"
- Navigated to Admin Dashboard
- Bottom navigation shows: Dashboard, Sales, Settings
- [ ] Pass [ ] Fail

### A3. Valid Login - Agent

**Test Case Name**: Agent login with valid credentials  
**Preconditions**: Agent account exists and is confirmed  
**Steps to Reproduce**:

1. Open login screen
2. Enter valid agent email
3. Enter correct password
4. Tap "Login"

**Expected Result**:

- Loading indicator appears
- Success toast shows "Login successful!"
- Navigated to Agent Dashboard
- Bottom navigation shows: Dashboard, History, Settings
- [ ] Pass [ ] Fail

### A4. Invalid Login Credentials

**Test Case Name**: Login with incorrect credentials  
**Preconditions**: App is on login screen  
**Steps to Reproduce**:

1. Enter non-existent email or wrong password
2. Tap "Login"

**Expected Result**:

- Error toast appears with authentication message
- User remains on login screen
- Form is not cleared
- [ ] Pass [ ] Fail

### A5. Email Validation

**Test Case Name**: Email format validation during registration  
**Preconditions**: On signup screen  
**Steps to Reproduce**:

1. Enter invalid email formats: "test", "test@", "test.com"
2. Try to proceed

**Expected Result**:

- Validation errors appear for invalid emails
- Form submission is prevented
- Field highlights invalid input
- [ ] Pass [ ] Fail

### A6. Password Strength Validation

**Test Case Name**: Password requirements during registration  
**Preconditions**: On signup screen  
**Steps to Reproduce**:

1. Try passwords: "123", "password", "Test1"
2. Try valid password: "TestPass123"

**Expected Result**:

- Weak passwords show validation errors
- Strong passwords are accepted
- Requirements are clearly displayed
- [ ] Pass [ ] Fail

### A7. Password Confirmation Mismatch

**Test Case Name**: Password confirmation validation  
**Preconditions**: On signup screen  
**Steps to Reproduce**:

1. Enter password: "TestPass123"
2. Enter confirm password: "TestPass124"
3. Try to submit

**Expected Result**:

- Validation error appears: "Passwords do not match"
- Form submission is prevented
- [ ] Pass [ ] Fail

---

## 📊 Admin Dashboard Features

### B1. Dashboard Data Loading

**Test Case Name**: Admin dashboard statistics display  
**Preconditions**: Logged in as admin with existing sales data  
**Steps to Reproduce**:

1. Navigate to Admin Dashboard
2. Pull to refresh

**Expected Result**:

- Loading indicator appears during data fetch
- Statistics cards show correct numbers:
  - Total Sales
  - Sales Agents
  - Completed Sales
  - Pending Sales
  - Total Sales Amount
- Stove progress bar displays inventory status
- Quick action tiles are visible
- [ ] Pass [ ] Fail

### B2. Dashboard Refresh Functionality

**Test Case Name**: Pull-to-refresh dashboard data  
**Preconditions**: Admin dashboard is loaded  
**Steps to Reproduce**:

1. Pull down on dashboard content
2. Wait for refresh to complete

**Expected Result**:

- Refresh indicator appears
- Data is refetched from server
- Updated statistics are displayed
- Success feedback is provided
- [ ] Pass [ ] Fail

### B3. Quick Action Navigation

**Test Case Name**: Dashboard quick action tiles navigation  
**Preconditions**: Admin dashboard is loaded  
**Steps to Reproduce**:

1. Tap "Start New Sale" tile
2. Go back, tap "Manage Sales Agents" tile
3. Go back, tap "View All Sales" tile
4. Go back, tap "Sync Offline Data" tile

**Expected Result**:

- Each tile navigates to correct screen
- Back navigation works properly
- No crashes or errors occur
- [ ] Pass [ ] Fail

### B4. Dashboard Offline Mode

**Test Case Name**: Dashboard behavior when offline  
**Preconditions**: Admin logged in, disconnect internet  
**Steps to Reproduce**:

1. Turn off internet connection
2. Navigate to dashboard
3. Try to refresh data

**Expected Result**:

- Cached data is displayed if available
- Offline indicator appears
- Error message for network issues
- Graceful degradation of features
- [ ] Pass [ ] Fail

---

## 💼 Sales Management (Admin)

### C1. View All Sales

**Test Case Name**: Sales list display and filtering  
**Preconditions**: Admin logged in, sales data exists  
**Steps to Reproduce**:

1. Navigate to Sales tab
2. View sales list
3. Try search functionality
4. Apply status filters

**Expected Result**:

- Sales list loads with proper data
- Each sale shows key information
- Search works by transaction ID, customer name
- Filters work for different status
- Pagination works if applicable
- [ ] Pass [ ] Fail

### C2. View Sale Details

**Test Case Name**: Individual sale details screen  
**Preconditions**: Sales list is loaded  
**Steps to Reproduce**:

1. Tap on any sale item in the list
2. Review all sale information

**Expected Result**:

- Sale details screen opens
- All sale information is displayed:
  - Transaction ID, stove serial, contact details
  - Address with map if available
  - Images (stove and agreement)
  - Signature
  - Status and timestamps
- [ ] Pass [ ] Fail

### C3. Update Sale Information

**Test Case Name**: Edit existing sale data  
**Preconditions**: Sale details screen is open  
**Steps to Reproduce**:

1. Tap edit/update button
2. Modify contact person name
3. Change phone number
4. Update address information
5. Save changes

**Expected Result**:

- Form pre-populated with existing data
- Changes are validated
- Updated data is saved successfully
- Confirmation message appears
- Sale list reflects changes
- [ ] Pass [ ] Fail

### C4. Sale Status Management

**Test Case Name**: Change sale status  
**Preconditions**: Sale details screen open  
**Steps to Reproduce**:

1. View sale with "incomplete" status
2. Update required fields
3. Add missing images/signature
4. Save sale

**Expected Result**:

- Status automatically updates based on completeness
- Status progression: incomplete → pending → completed
- Status badges display correctly
- [ ] Pass [ ] Fail

### C5. Sales Export Functionality

**Test Case Name**: Export sales data  
**Preconditions**: Sales list is loaded  
**Steps to Reproduce**:

1. Navigate to sales management
2. Look for export options
3. Try to export filtered data

**Expected Result**:

- Export functionality is available
- Data exports in appropriate format
- Filtered data exports correctly
- [ ] Pass [ ] Fail

### C6. Sales Search and Filter

**Test Case Name**: Search and filter sales records  
**Preconditions**: Sales list with multiple records  
**Steps to Reproduce**:

1. Use search bar to search by:
   - Transaction ID
   - Customer name
   - Phone number
2. Apply filters:
   - Status (completed, pending, incomplete)
   - Date range
   - Agent

**Expected Result**:

- Search returns relevant results
- Filters work correctly
- Combined search and filter work
- Clear filters option works
- [ ] Pass [ ] Fail

---

## 🧑‍💼 Sales Agent Management (Admin)

### D1. View Sales Agents List

**Test Case Name**: Display all sales agents  
**Preconditions**: Admin logged in, agents exist  
**Steps to Reproduce**:

1. Navigate to dashboard
2. Tap "Manage Sales Agents"
3. View agents list

**Expected Result**:

- All agents in organization are displayed
- Agent information shows: name, email, phone, status
- Loading states work properly
- [ ] Pass [ ] Fail

### D2. Add New Sales Agent

**Test Case Name**: Create new agent account  
**Preconditions**: On manage agents screen  
**Steps to Reproduce**:

1. Tap "Add Agent" button
2. Fill in required information:
   - Full name
   - Email address
   - Phone number
   - Password
3. Submit form

**Expected Result**:

- Form validation works correctly
- Agent is created successfully
- Agent appears in agents list
- Confirmation message appears
- [ ] Pass [ ] Fail

### D3. View Agent Details

**Test Case Name**: Individual agent information  
**Preconditions**: Agents list is loaded  
**Steps to Reproduce**:

1. Tap on any agent in the list
2. Review agent profile

**Expected Result**:

- Agent details screen opens
- Complete agent information displayed
- Agent's sales performance visible
- Contact information accessible
- [ ] Pass [ ] Fail

### D4. Update Agent Information

**Test Case Name**: Edit agent profile  
**Preconditions**: Agent details screen open  
**Steps to Reproduce**:

1. Tap edit button
2. Update agent information
3. Save changes

**Expected Result**:

- Edit form pre-populated
- Changes save successfully
- Agent list reflects updates
- [ ] Pass [ ] Fail

### D5. Deactivate Agent

**Test Case Name**: Disable agent account  
**Preconditions**: Agent details screen open  
**Steps to Reproduce**:

1. Look for deactivate option
2. Confirm deactivation
3. Check agent status

**Expected Result**:

- Deactivation confirmation dialog appears
- Agent status changes to inactive
- Agent cannot log in
- [ ] Pass [ ] Fail

### D6. Agent Performance Metrics

**Test Case Name**: View agent sales statistics  
**Preconditions**: Agent with sales history  
**Steps to Reproduce**:

1. Open agent details
2. View performance section

**Expected Result**:

- Sales count is displayed
- Performance metrics are accurate
- Date range filters work
- [ ] Pass [ ] Fail

---

## 📱 Agent Dashboard Features

### E1. Agent Dashboard Loading

**Test Case Name**: Agent dashboard data display  
**Preconditions**: Logged in as agent  
**Steps to Reproduce**:

1. Navigate to Agent Dashboard
2. Check all dashboard elements

**Expected Result**:

- Welcome message with agent name
- Summary boxes show relevant statistics
- Quick action tiles are available
- Offline status banner if applicable
- [ ] Pass [ ] Fail

### E2. Agent Quick Actions

**Test Case Name**: Agent dashboard action tiles  
**Preconditions**: Agent dashboard loaded  
**Steps to Reproduce**:

1. Tap "Start New Sale"
2. Go back, tap "View Offline Records"
3. Test other available actions

**Expected Result**:

- Each action navigates correctly
- Proper permissions are enforced
- No unauthorized access to admin features
- [ ] Pass [ ] Fail

### E3. Agent Sales Summary

**Test Case Name**: Agent personal sales statistics  
**Preconditions**: Agent with sales history  
**Steps to Reproduce**:

1. View dashboard summary boxes
2. Check numbers accuracy

**Expected Result**:

- Personal sales count is correct
- Only agent's own sales are counted
- Statistics update properly
- [ ] Pass [ ] Fail

---

## 📝 Sales Form (Agent)

### F1. New Sale Creation

**Test Case Name**: Complete sales form submission  
**Preconditions**: Agent logged in  
**Steps to Reproduce**:

1. Navigate to "Start New Sale"
2. Fill end-user information:
   - Full name
   - Phone number
   - Address
3. Select stove ID from dropdown
4. Capture stove image
5. Capture agreement document image
6. Add digital signature
7. Submit form

**Expected Result**:

- All form fields validate correctly
- Images capture and display properly
- Signature capture works
- Form submits successfully
- Confirmation message appears
- Sale appears in agent's history
- [ ] Pass [ ] Fail

### F2. Form Validation

**Test Case Name**: Sales form field validation  
**Preconditions**: On new sale form  
**Steps to Reproduce**:

1. Try to submit empty form
2. Enter invalid phone numbers
3. Try to submit without required images
4. Try to submit without signature

**Expected Result**:

- Required field validation prevents submission
- Invalid phone number format rejected
- Missing images prevent submission
- Missing signature prevents submission
- Clear error messages displayed
- [ ] Pass [ ] Fail

### F3. Stove ID Selection

**Test Case Name**: Available stove IDs dropdown  
**Preconditions**: Sales form open  
**Steps to Reproduce**:

1. Tap stove ID dropdown
2. View available options
3. Select a stove ID

**Expected Result**:

- Only available stove IDs are shown
- Selection updates form
- Unavailable stoves are not listed
- [ ] Pass [ ] Fail

### F4. Image Capture - Stove Photo

**Test Case Name**: Stove image capture functionality  
**Preconditions**: Sales form open  
**Steps to Reproduce**:

1. Tap "Capture Stove Image"
2. Choose camera or gallery
3. Take/select photo
4. Confirm image

**Expected Result**:

- Camera opens properly
- Photo is captured successfully
- Image appears in form preview
- Image quality is acceptable
- [ ] Pass [ ] Fail

### F5. Image Capture - Agreement Document

**Test Case Name**: Agreement document image capture  
**Preconditions**: Sales form open  
**Steps to Reproduce**:

1. Tap "Capture Agreement"
2. Choose camera or gallery
3. Take/select document photo
4. Confirm image

**Expected Result**:

- Camera opens properly
- Document is captured clearly
- Image appears in form preview
- Image quality is acceptable
- [ ] Pass [ ] Fail

### F6. Digital Signature Capture

**Test Case Name**: Signature pad functionality  
**Preconditions**: Sales form open  
**Steps to Reproduce**:

1. Scroll to signature section
2. Draw signature on pad
3. Clear signature and redraw
4. Save signature

**Expected Result**:

- Signature pad is responsive
- Drawing works smoothly
- Clear function works
- Signature is saved properly
- [ ] Pass [ ] Fail

### F7. Geolocation Capture

**Test Case Name**: GPS coordinates capture  
**Preconditions**: Sales form open, location permissions granted  
**Steps to Reproduce**:

1. Check current location display
2. Verify GPS coordinates appear
3. Try manual coordinate entry

**Expected Result**:

- GPS coordinates are captured automatically
- Location accuracy is reasonable
- Manual entry option works
- Coordinates format is correct
- [ ] Pass [ ] Fail

### F8. Offline Sale Submission

**Test Case Name**: Form submission while offline  
**Preconditions**: Sales form filled, no internet connection  
**Steps to Reproduce**:

1. Disconnect internet
2. Complete sales form
3. Submit form
4. Check offline storage

**Expected Result**:

- Form saves to offline storage
- Success message indicates offline save
- Data stored locally
- Sync indicator appears
- [ ] Pass [ ] Fail

### F9. Edit Existing Sale

**Test Case Name**: Modify previously created sale  
**Preconditions**: Agent has existing sales  
**Steps to Reproduce**:

1. Navigate to sales history
2. Select a sale to edit
3. Modify information
4. Save changes

**Expected Result**:

- Edit form pre-populated
- Changes are validated
- Updates save successfully
- History reflects changes
- [ ] Pass [ ] Fail

---

## 📚 Sales History (Agent)

### G1. View Sales History

**Test Case Name**: Agent sales history display  
**Preconditions**: Agent with sales records  
**Steps to Reproduce**:

1. Navigate to History tab
2. View sales list
3. Check sorting options

**Expected Result**:

- All agent's sales are displayed
- Most recent sales appear first
- Sale status is clearly indicated
- Loading works properly
- [ ] Pass [ ] Fail

### G2. Sales History Search

**Test Case Name**: Search functionality in history  
**Preconditions**: Sales history loaded  
**Steps to Reproduce**:

1. Use search bar
2. Search by customer name
3. Search by transaction ID
4. Search by phone number

**Expected Result**:

- Search returns relevant results
- Search is case-insensitive
- Clear search works
- No matches shows appropriate message
- [ ] Pass [ ] Fail

### G3. Sales History Filtering

**Test Case Name**: Filter sales by status  
**Preconditions**: Sales history with mixed statuses  
**Steps to Reproduce**:

1. Apply status filters
2. Filter by date range
3. Combine multiple filters

**Expected Result**:

- Filters work correctly
- Multiple filters can be combined
- Clear filters option works
- Filtered count is accurate
- [ ] Pass [ ] Fail

### G4. Sale Detail View from History

**Test Case Name**: View sale details from history  
**Preconditions**: Sales history loaded  
**Steps to Reproduce**:

1. Tap on any sale in history
2. Review all sale details

**Expected Result**:

- Sale details screen opens
- All information is displayed correctly
- Images load properly
- Edit option is available if applicable
- [ ] Pass [ ] Fail

---

## 🔄 Offline Data Management

### H1. Offline Mode Toggle

**Test Case Name**: Enable/disable offline mode  
**Preconditions**: In Settings screen  
**Steps to Reproduce**:

1. Navigate to Settings
2. Find offline data section
3. Toggle offline mode
4. Observe changes

**Expected Result**:

- Toggle switches offline mode on/off
- Offline banner appears when enabled
- Data syncing behavior changes
- Status is clearly indicated
- [ ] Pass [ ] Fail

### H2. Offline Data Storage

**Test Case Name**: Data saves locally when offline  
**Preconditions**: Offline mode enabled, no internet  
**Steps to Reproduce**:

1. Create new sale while offline
2. Edit existing sale while offline
3. Check offline records

**Expected Result**:

- Data saves to local storage
- Offline status is indicated
- Changes are queued for sync
- No data loss occurs
- [ ] Pass [ ] Fail

### H3. Offline Data Sync

**Test Case Name**: Sync offline data when back online  
**Preconditions**: Offline data exists, internet restored  
**Steps to Reproduce**:

1. Go to Settings > Offline Data
2. Tap "Sync Offline Data"
3. Monitor sync progress

**Expected Result**:

- Sync process starts automatically
- Progress indicator shows status
- Sync completes successfully
- Success confirmation appears
- Local data is marked as synced
- [ ] Pass [ ] Fail

### H4. View Offline Records

**Test Case Name**: Display offline sales records  
**Preconditions**: Offline sales exist  
**Steps to Reproduce**:

1. Navigate to "View Offline Records"
2. Check offline sales list
3. View individual offline sale details

**Expected Result**:

- All offline records are listed
- Sync status is clearly shown
- Offline records are distinguishable
- Details view works properly
- [ ] Pass [ ] Fail

### H5. Sync Conflict Resolution

**Test Case Name**: Handle sync conflicts  
**Preconditions**: Same sale edited offline and online  
**Steps to Reproduce**:

1. Edit sale while offline
2. Same sale edited by admin online
3. Attempt to sync

**Expected Result**:

- Conflict is detected
- User is notified of conflict
- Resolution options are provided
- Data integrity is maintained
- [ ] Pass [ ] Fail

### H6. Offline Data Clear

**Test Case Name**: Clear all offline data  
**Preconditions**: Offline data exists  
**Steps to Reproduce**:

1. Go to Settings > Offline Data
2. Tap "Clear Offline Data"
3. Confirm action

**Expected Result**:

- Confirmation dialog appears
- All offline data is cleared
- Storage space is freed
- Confirmation message appears
- [ ] Pass [ ] Fail

---

## ⚙️ Settings & Profile Management

### I1. View Profile Information

**Test Case Name**: Display user profile details  
**Preconditions**: User logged in  
**Steps to Reproduce**:

1. Navigate to Settings
2. Tap "Profile"
3. Review all profile information

**Expected Result**:

- Complete profile information displayed
- Personal details are accurate
- Organization information shown
- Account status is visible
- [ ] Pass [ ] Fail

### I2. Update Profile Information

**Test Case Name**: Edit profile details  
**Preconditions**: Profile screen open  
**Steps to Reproduce**:

1. Tap edit profile button
2. Update editable fields (name, phone)
3. Save changes

**Expected Result**:

- Edit form opens properly
- Only editable fields are modifiable
- Changes save successfully
- Profile reflects updates
- [ ] Pass [ ] Fail

### I3. Change Password

**Test Case Name**: Update user password  
**Preconditions**: Profile screen open  
**Steps to Reproduce**:

1. Tap "Change Password" button
2. Enter current password
3. Enter new password
4. Confirm new password
5. Submit change

**Expected Result**:

- Change password form opens
- Current password validation works
- New password requirements enforced
- Password change succeeds
- Success confirmation appears
- [ ] Pass [ ] Fail

### I4. Settings Navigation

**Test Case Name**: Navigate through settings options  
**Preconditions**: Settings screen open  
**Steps to Reproduce**:

1. Tap each settings option:
   - Profile
   - Security
   - FAQ
   - Chat Support
   - Offline Data

**Expected Result**:

- Each option navigates correctly
- Appropriate screens open
- Back navigation works
- No crashes occur
- [ ] Pass [ ] Fail

### I5. Password Change Validation

**Test Case Name**: Password change field validation  
**Preconditions**: Change password form open  
**Steps to Reproduce**:

1. Enter wrong current password
2. Enter weak new password
3. Enter non-matching confirmation
4. Try to submit

**Expected Result**:

- Current password validation fails
- Weak password is rejected
- Password mismatch is caught
- Form submission is prevented
- Clear error messages shown
- [ ] Pass [ ] Fail

---

## 🚪 Logout & Session Management

### J1. Standard Logout

**Test Case Name**: Logout without offline data  
**Preconditions**: User logged in, no offline data  
**Steps to Reproduce**:

1. Navigate to Settings
2. Tap "Logout"
3. Confirm logout

**Expected Result**:

- Logout confirmation dialog appears
- No offline data warning shown
- Logout completes successfully
- Redirected to login screen
- Session is cleared completely
- [ ] Pass [ ] Fail

### J2. Logout with Offline Data Warning

**Test Case Name**: Logout with unsaved offline data  
**Preconditions**: User logged in, offline data exists  
**Steps to Reproduce**:

1. Create some offline sales
2. Navigate to Settings
3. Tap "Logout"
4. Review warning message

**Expected Result**:

- Logout warning dialog appears
- Offline data count is shown
- Warning about data loss displayed
- Options to sync or proceed shown
- [ ] Pass [ ] Fail

### J3. Force Logout with Data Loss

**Test Case Name**: Logout and clear offline data  
**Preconditions**: Offline data exists  
**Steps to Reproduce**:

1. Attempt logout with offline data
2. Choose to proceed despite warning
3. Confirm data loss

**Expected Result**:

- Final confirmation dialog appears
- All offline data is cleared
- Logout completes successfully
- No data remains locally
- [ ] Pass [ ] Fail

### J4. Session Expiry Handling

**Test Case Name**: Handle expired authentication  
**Preconditions**: Long app session  
**Steps to Reproduce**:

1. Leave app open for extended time
2. Try to perform authenticated action
3. Observe session handling

**Expected Result**:

- Session expiry is detected
- User is notified appropriately
- Automatic redirect to login
- Data is preserved if possible
- [ ] Pass [ ] Fail

---

## 🌐 Network & Connectivity

### K1. Network Connection Lost

**Test Case Name**: Handle network disconnection  
**Preconditions**: App in use, stable connection  
**Steps to Reproduce**:

1. Disable device connectivity
2. Try to perform online actions
3. Observe app behavior

**Expected Result**:

- Network loss is detected
- Offline mode activates automatically
- User is notified of offline status
- Local functionality continues working
- [ ] Pass [ ] Fail

### K2. Network Connection Restored

**Test Case Name**: Handle network reconnection  
**Preconditions**: App in offline mode  
**Steps to Reproduce**:

1. Restore device connectivity
2. Check app behavior
3. Try online actions

**Expected Result**:

- Network restoration is detected
- Online mode activates automatically
- Pending sync operations start
- Online functionality is restored
- [ ] Pass [ ] Fail

### K3. Poor Network Conditions

**Test Case Name**: App behavior with slow connection  
**Preconditions**: Simulate slow network  
**Steps to Reproduce**:

1. Use app with very slow connection
2. Try to load data
3. Submit forms

**Expected Result**:

- Loading indicators appear
- Timeouts are handled gracefully
- User gets appropriate feedback
- App doesn't freeze or crash
- [ ] Pass [ ] Fail

### K4. API Error Handling

**Test Case Name**: Handle server errors  
**Preconditions**: App connected to server  
**Steps to Reproduce**:

1. Simulate server errors (500, 404, etc.)
2. Try various app operations
3. Check error handling

**Expected Result**:

- Server errors are caught properly
- User-friendly error messages shown
- App doesn't crash
- Retry mechanisms work where appropriate
- [ ] Pass [ ] Fail

---

## 📁 Data Integrity & Edge Cases

### L1. Large Dataset Handling

**Test Case Name**: App performance with many sales  
**Preconditions**: Large number of sales records  
**Steps to Reproduce**:

1. Load sales list with 100+ records
2. Navigate through pages
3. Search and filter data

**Expected Result**:

- App loads data efficiently
- Pagination works properly
- Search remains responsive
- No memory issues occur
- [ ] Pass [ ] Fail

### L2. Image Handling

**Test Case Name**: Various image scenarios  
**Preconditions**: Sales form or update screen  
**Steps to Reproduce**:

1. Upload very large images
2. Upload images in different formats
3. Try uploading corrupted files
4. Handle camera permission denial

**Expected Result**:

- Large images are compressed properly
- Supported formats work correctly
- Invalid files are rejected gracefully
- Permission handling is smooth
- [ ] Pass [ ] Fail

### L3. Concurrent User Actions

**Test Case Name**: Multiple users editing same data  
**Preconditions**: Multiple user accounts  
**Steps to Reproduce**:

1. Have admin and agent edit same sale
2. Submit changes simultaneously
3. Check data consistency

**Expected Result**:

- Conflicts are detected
- Data integrity is maintained
- Users are notified of conflicts
- Resolution mechanism works
- [ ] Pass [ ] Fail

### L4. App State Recovery

**Test Case Name**: Recover from app crash/kill  
**Preconditions**: App in use  
**Steps to Reproduce**:

1. Force close app during form filling
2. Restart app
3. Check data preservation

**Expected Result**:

- App restarts properly
- Draft data is preserved where possible
- User is returned to appropriate screen
- No data corruption occurs
- [ ] Pass [ ] Fail

### L5. Device Storage Limits

**Test Case Name**: Handle storage space issues  
**Preconditions**: Device with limited storage  
**Steps to Reproduce**:

1. Fill device storage to near capacity
2. Try to save offline data
3. Capture images

**Expected Result**:

- Storage issues are detected
- User is warned of storage problems
- App handles gracefully
- Critical functionality is preserved
- [ ] Pass [ ] Fail

---

## 🔒 Security & Permissions

### M1. Role-Based Access Control

**Test Case Name**: Verify role-based restrictions  
**Preconditions**: Both admin and agent accounts  
**Steps to Reproduce**:

1. Login as agent
2. Try to access admin-only features
3. Login as admin
4. Verify full access

**Expected Result**:

- Agents cannot access admin features
- Proper error messages for unauthorized access
- Admins have full access
- Role enforcement is consistent
- [ ] Pass [ ] Fail

### M2. Data Privacy

**Test Case Name**: User data isolation  
**Preconditions**: Multiple organizations/users  
**Steps to Reproduce**:

1. Login as user from Organization A
2. Check data visibility
3. Switch to user from Organization B
4. Verify data isolation

**Expected Result**:

- Users only see their organization's data
- No data leakage between organizations
- Agent sees only their own sales
- Admin sees all org sales
- [ ] Pass [ ] Fail

### M3. Authentication Token Handling

**Test Case Name**: Token security and refresh  
**Preconditions**: Logged in user  
**Steps to Reproduce**:

1. Monitor token expiry
2. Check token refresh mechanism
3. Test invalid token handling

**Expected Result**:

- Tokens are handled securely
- Refresh works automatically
- Invalid tokens trigger re-auth
- No sensitive data exposure
- [ ] Pass [ ] Fail

### M4. Device Permissions

**Test Case Name**: Handle device permission requests  
**Preconditions**: Fresh app install  
**Steps to Reproduce**:

1. Try to capture images (camera permission)
2. Try to get location (location permission)
3. Test permission denial scenarios

**Expected Result**:

- Permission requests are clear
- Denial is handled gracefully
- Alternative options provided
- App doesn't crash on denial
- [ ] Pass [ ] Fail

---

## 📊 Performance & Usability

### N1. App Launch Time

**Test Case Name**: App startup performance  
**Preconditions**: App closed  
**Steps to Reproduce**:

1. Launch app from device home screen
2. Measure time to usable state
3. Test cold vs warm starts

**Expected Result**:

- App launches within reasonable time (<3s)
- Splash screen displays properly
- Initial screen loads smoothly
- No frozen or black screens
- [ ] Pass [ ] Fail

### N2. Screen Rotation Handling

**Test Case Name**: Orientation change behavior  
**Preconditions**: App in use  
**Steps to Reproduce**:

1. Use app in portrait mode
2. Rotate device to landscape
3. Rotate back to portrait
4. Test on different screens

**Expected Result**:

- Screen rotation works smoothly
- Layout adapts properly
- Data is preserved during rotation
- No crashes or display issues
- [ ] Pass [ ] Fail

### N3. Memory Usage

**Test Case Name**: App memory consumption  
**Preconditions**: Device with memory monitoring  
**Steps to Reproduce**:

1. Use app for extended period
2. Navigate through all screens
3. Load large datasets
4. Monitor memory usage

**Expected Result**:

- Memory usage remains reasonable
- No significant memory leaks
- App doesn't cause device slowdown
- Background memory cleanup works
- [ ] Pass [ ] Fail

### N4. Battery Usage

**Test Case Name**: App power consumption  
**Preconditions**: Device with battery monitoring  
**Steps to Reproduce**:

1. Use app for extended period
2. Check battery usage statistics
3. Test background behavior

**Expected Result**:

- Battery usage is reasonable
- No excessive drain when idle
- Background operations are efficient
- Power saving modes respected
- [ ] Pass [ ] Fail

---

## 🐛 Error Scenarios & Edge Cases

### O1. Form Validation Edge Cases

**Test Case Name**: Unusual form input handling  
**Preconditions**: Various app forms  
**Steps to Reproduce**:

1. Enter extremely long text in fields
2. Use special characters and emojis
3. Paste large amounts of text
4. Test Unicode characters

**Expected Result**:

- Long text is handled gracefully
- Special characters don't break forms
- Text limits are enforced
- Unicode support works properly
- [ ] Pass [ ] Fail

### O2. Corrupted Data Recovery

**Test Case Name**: Handle corrupted local data  
**Preconditions**: App with local data  
**Steps to Reproduce**:

1. Simulate corrupted local storage
2. Restart app
3. Check data recovery

**Expected Result**:

- Corrupted data is detected
- App doesn't crash
- Data recovery mechanisms work
- User is informed appropriately
- [ ] Pass [ ] Fail

### O3. Timestamp and Date Handling

**Test Case Name**: Date/time edge cases  
**Preconditions**: App forms with dates  
**Steps to Reproduce**:

1. Test timezone changes
2. Test daylight saving transitions
3. Test date boundary cases
4. Test future dates

**Expected Result**:

- Timezone handling is correct
- Date calculations are accurate
- Invalid dates are rejected
- Date display is consistent
- [ ] Pass [ ] Fail

### O4. Rapid User Interactions

**Test Case Name**: Handle rapid tapping/inputs  
**Preconditions**: App interactive elements  
**Steps to Reproduce**:

1. Rapidly tap buttons multiple times
2. Quickly navigate between screens
3. Submit forms rapidly

**Expected Result**:

- Duplicate actions are prevented
- App remains responsive
- No crashes or inconsistent states
- Rate limiting works properly
- [ ] Pass [ ] Fail

---

## Test Completion Summary

### Overall Test Statistics

- **Total Test Cases**: 70+
- **Authentication Tests**: 7
- **Admin Dashboard Tests**: 4
- **Sales Management Tests**: 6
- **Agent Management Tests**: 6
- **Agent Dashboard Tests**: 3
- **Sales Form Tests**: 9
- **Sales History Tests**: 4
- **Offline Management Tests**: 6
- **Settings/Profile Tests**: 5
- **Logout/Session Tests**: 4
- **Network/Connectivity Tests**: 4
- **Data Integrity Tests**: 5
- **Security/Permissions Tests**: 4
- **Performance Tests**: 4
- **Error/Edge Cases Tests**: 4

### Test Sign-off

**Tester Name**: ******\_\_\_\_******  
**Date**: ******\_\_\_\_******  
**Environment**: ******\_\_\_\_******  
**Overall Status**: [ ] Pass [ ] Fail  
**Critical Issues Found**: ******\_\_\_\_******  
**Comments**: ******\_\_\_\_******

---

## Notes for Testers

1. **Test Data Setup**: Ensure you have proper test accounts for both admin and agent roles
2. **Device Variations**: Test on different device sizes and OS versions
3. **Network Simulation**: Use network simulation tools for connectivity testing
4. **Image Testing**: Have various test images ready (different sizes, formats)
5. **Documentation**: Document any bugs found with steps to reproduce
6. **Performance**: Note any performance issues or unusually slow operations
7. **Accessibility**: Consider testing with accessibility features enabled
8. **Real-world Scenarios**: Test with realistic data volumes and usage patterns

---

**Version**: 1.0  
**Last Updated**: September 17, 2025  
**Application Version**: [Current App Version]
