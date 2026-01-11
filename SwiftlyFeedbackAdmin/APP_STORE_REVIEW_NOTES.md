# App Store Review Notes - Feedback Kit Admin

Use this template when submitting to App Store Connect. Copy the relevant sections into the "App Review Information" fields.

---

## Demo Account Credentials

**Email:** `reviewer@feedbackkit.app`
**Password:** `ReviewerPass123!`

> **Note:** Create this demo account before submission with pre-populated sample data (projects, feedback items, comments).

---

## Review Notes (Copy to App Store Connect)

```
DEMO ACCOUNT
Email: reviewer@feedbackkit.app
Password: ReviewerPass123!

This account has sample projects and feedback pre-configured for testing.

HOW TO TEST KEY FEATURES

1. Projects
   - View projects on the Projects tab
   - Tap a project to see details, members, and settings
   - Access project integrations via the ⋯ menu

2. Feedback Management
   - Tap the Feedback tab to view all feedback items
   - Switch between List and Kanban views using the segmented control
   - Tap any feedback item to view details, comments, and vote count
   - Use multi-select to merge feedback items or perform bulk actions

3. Analytics
   - Home tab shows dashboard with KPIs and feedback statistics
   - Users tab shows SDK users and session data
   - Events tab shows analytics charts with time period filters (7d, 30d, 90d, 1y)

4. Integrations (Team tier feature)
   - Project Details > ⋯ menu > [Integration] Integration
   - Supports: Slack, GitHub, Notion, Linear, ClickUp, Monday.com
   - Demo account has Team tier access for testing

SUBSCRIPTION TIERS
- Free: 1 project, 10 feedback items per project
- Pro: 2 projects, unlimited feedback, advanced analytics
- Team: Unlimited projects, team members, integrations

The demo account has Team tier access to demonstrate all features.

PERMISSIONS USED
- Camera: Optional, for uploading feedback attachments
- Photo Library: Optional, for selecting images to attach to feedback

NO SPECIAL HARDWARE REQUIRED
This app can be fully tested on any iPhone or iPad simulator/device.
```

---

## What's New in This Version (Example)

```
• Bug fixes and performance improvements
```

---

## Notes for Specific Features

### If Adding In-App Purchases

```
IN-APP PURCHASES
- Feedback Kit Pro (Monthly): Unlocks 2 projects, unlimited feedback, advanced analytics
- Feedback Kit Pro (Yearly): Same as monthly with 2 months free
- Feedback Kit Team (Monthly): Unlocks team members, integrations, unlimited projects
- Feedback Kit Team (Yearly): Same as monthly with 2 months free

To test purchases: Use sandbox tester credentials provided separately.
```

### If Using Push Notifications

```
PUSH NOTIFICATIONS
Users receive notifications for:
- New feedback submitted to their projects
- New comments on feedback items
- Status changes on feedback they've voted on

Notifications can be managed in Settings > Notifications.
```

### If Rejected for Login Issues

```
ADDITIONAL LOGIN NOTES
1. Launch the app
2. Tap "Sign In" on the welcome screen (or tap "Already have an account?" during onboarding)
3. Enter the demo credentials above
4. The app will show the main dashboard with sample data

If email verification is requested, the demo account is pre-verified.
```

---

## Pre-Submission Checklist

- [ ] Demo account created and tested on production server
- [ ] Demo account has sample projects with feedback items
- [ ] Demo account has Team tier subscription for full feature access
- [ ] All test/debug features disabled in release build
- [ ] Privacy Policy URL is valid and accessible
- [ ] Support URL is valid and accessible
- [ ] App screenshots are current and match the submitted build
- [ ] App description accurately reflects current features

---

## Common Rejection Reasons to Avoid

1. **Guideline 2.1 - App Completeness**
   - Ensure all features work with demo credentials
   - No placeholder content or "coming soon" sections

2. **Guideline 4.0 - Design**
   - App should have sufficient content to be useful
   - Demo account must have realistic sample data

3. **Guideline 5.1.1 - Data Collection**
   - Privacy policy must be accessible
   - App must accurately describe data collection in App Privacy section

4. **Guideline 3.1.1 - In-App Purchase**
   - All subscription features must be accessible via IAP
   - No external payment links for digital content
