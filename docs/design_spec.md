# Project Overview 

1.1 Purpose

Lambdas Xi Chapter is a private, invite-only iOS application designed to strengthen connections between fraternity alumni and active members through structured, service-first interactions.

The core mechanic is a system of small unpaid “bounties” (tasks, requests, or favors) that members can post and complete. These bounties create a low-friction, trust-building way to start relationships that can grow into long-term mentorship and community connection.

2. Core Principles (Non-Negotiables)

Service before networking
First interactions are driven by helping, not cold outreach.

Private and trusted
Access is restricted via invite code.

Humanized profiles
Every member is visible and contextualized.

Guided interaction
The app nudges users toward healthy, meaningful engagement.

Mobile-native
Designed specifically for iOS.

3. Platform Scope

Platform: Native iOS

Target OS: iOS 17+

Device Support: iPhone (iPad optional, responsive layout recommended)

Distribution: Apple App Store

User Base: Single fraternity chapter only

4. Access Control & Onboarding
4.1 App Lock (First Launch)

On first launch, the app is fully locked.

Flow

User opens app

Screen displays:

App branding

Text input: “Enter Invite Code”

Button: “Unlock”

User must enter: HELLOPANDA

Outcomes

If correct:

App unlocks

User proceeds to authentication

If incorrect:

Error message displayed

App remains locked

Security Requirement (Mandatory)

Invite code validation must be enforced:

Client-side

Server-side

5. Authentication
5.1 Method

Email Magic Link Authentication

5.2 Flow

User enters email

Backend sends a secure, time-limited login link

User taps link on iPhone

App deep-links and authenticates user session

User is logged in

5.3 Security Requirements

Token expiration: max 15 minutes

Single-use tokens

Encrypted token storage (iOS Keychain)

Session refresh mechanism

Backend session validation on every API call

6. Profile System (ALL FIELDS REQUIRED)
6.1 Gating Rule

Users must complete their profile before accessing the app.

6.2 Required Fields (ALL REQUIRED)

Full Name

Chapter class (text)

Role Tag (Alumni / Active)

Graduation Year

Major or Industry

Skills (2–3)

Short Bio

6.3 Skills System
6.3.1 Predefined Tags

Graphic Design

Web Development

Video Editing

Social Media

Marketing

Writing

Photography

Data / Excel

Errands / In-Person Help

6.3.2 Custom Skill Entry

Free-text field

Stored alongside structured tags

7. App Navigation Structure
7.1 Tab Bar (Bottom Navigation)

Discovery

Messages

Bounties

News

Profile

8. Discovery Feature
8.1 Discovery Feed

Scrollable list of profile cards showing:

Profile photo

Name

Role tag badge

Graduation year

Skills

Bio preview

Button: “View Profile”

Button: “Message”

8.2 Filters

Role (Alumni / Active)

Skills

Graduation year

8.3 Messaging from Discovery

One-to-one chat

In-app only

No email, phone number, or external links revealed

9. Bounty System
9.1 Who Can Create

All users (alumni and actives)

9.2 Bounty Fields

Title

Description

Skill tags

Estimated effort

Deadline (optional)

Creator (linked profile)

Status:

Open

In Progress

Completed

9.3 Bounty Feed

Visible to all users

Filterable by

Skill tags

Status

Creator role

10. Bounty Application Flow
10.1 Applying

Button: “Apply”

Optional short message field

Submits an application record

10.2 Creator View

For each bounty, creator sees:

List of applicants

Applicant profile previews

Application messages

Button: “Accept” on one applicant

11. Bounty Acceptance → Chat System (MANDATORY FLOW)

This flow is required and must happen exactly as defined.

Step 1: Accept

Creator selects an applicant

Bounty status changes to In Progress

Step 2: Push Notifications (APNs)

Both users receive:

Title: “LPhiE Bounty Accepted”

Body: “You’ve been matched for a bounty. Open chat to get started.”

Step 3: Chat Creation

System creates a dedicated one-to-one chat thread

Chat opens automatically

Step 4: Pinned Bounty Context UI (Permanent Header)

At the top of the chat:

Bounty title

Description preview

Skill tags

Status: In Progress

Button: “View Bounty”

This header remains permanently visible.

Step 5: Creator Prompt (Soft UI Prompt)

System displays to bounty creator:

“Introduce yourself (name, class) and share any additional details to get started.”

Step 6: Completion (MANDATORY)

Creator must mark bounty as Completed

Status updates globally

Both users receive push notification:

Title: “LPhiE Bounty Completed”

Body: “This bounty has been marked as completed.”

Chat remains open indefinitely

12. Messaging System
12.1 Scope

One-to-one only

Text-only

Linked to user accounts

Bounty-linked chats include the context header

12.2 Push Notifications Sent For

New message

Bounty application

Bounty accepted

Bounty completed

13. News / Legacy Section
13.1 Feed

Chronological list of posts

13.2 Supports

Text

Images

Newsletter-style content:

PDF-rendered or extracted text/images

13.3 Permissions

Read-only for users

Admin posting (manual backend role)

14. Push Notification Architecture
14.1 Service

Apple Push Notification Service (APNs)

14.2 Token Handling

Device token registered at login

Token refreshed on app launch

Token stored server-side per user

14.3 Notification Routing (Backend sends)

New bounty application → Creator

Bounty accepted → Applicant

Bounty completed → Both

New message → Recipient

15. iOS Architecture (Engineering Standard)
15.1 Frontend Stack

Swift

SwiftUI

MVVM Architecture

Combine or async/await for state handling

15.2 App Layers

View (SwiftUI screens)

ViewModel (business logic)

Service Layer (API, Auth, Notifications)

Models (DTOs + domain models)

15.3 Local Storage

Keychain: Auth tokens

UserDefaults: Invite code unlock flag

Optional CoreData for offline caching

16. Backend Architecture (Mobile-First Design)
16.1 API Style

REST or RPC

JSON

Token-authenticated requests

16.2 Core Services

Auth service (magic link)

User/profile service

Bounty service

Messaging service

Notification service

News service

16.3 Data Models (Conceptual)

User

Profile

Skill

Bounty

Application

Chat

Message

DeviceToken

NewsPost

17. Security & Best Practices
17.1 iOS

Encrypted token storage (Keychain)

SSL pinning recommended

Background notification handling

App Transport Security enforced

17.2 Backend

Rate limiting

Invite code validation

Auth middleware

Role tag validation

Input sanitization

Secure token generation

18. App Store Compliance

Magic link auth supported

No payments

No user tracking

Privacy policy required

Terms of service required

Data deletion mechanism required

19. Error Handling
19.1 Required UI States

No internet connection

Expired login link

Invalid invite code

Failed notification registration

API failure fallback states

20. Performance Requirements

App launch < 2 seconds

Feed scroll at 60fps

Push delivery < 5 seconds typical

Chat messages real-time

21. UI / Visual Style Guide (Based on Your Image)

Your screenshot shows a clean “news-style” iOS design language. Lambdas Xi Chapter should adopt that same aesthetic across Discovery, Bounties, and News.

21.1 Design Tone

Minimal, editorial, “content-first”

Lots of whitespace

Thin separators, subtle borders

Cards for list items

Calm neutral palette

21.2 Layout Patterns (Match the screenshot)

Top header with large title on left (e.g., “Lambdas Xi Chapter”) and a single icon button on right (notifications/settings)

Rounded search bar beneath header

Category/segment tabs near top (like “All / Alumni / Active” or “All / Open / In Progress / Completed”)

Card-based feed rows:

Left thumbnail/image (profile photo or bounty icon)

Right text stack (category tag, title, subtitle/meta)

“…” overflow menu icon on the far right where relevant

21.3 Typography

Headlines: editorial-style (serif-like feel in the screenshot)

Body/meta text: clean sans-serif system styling

Strong hierarchy:

Big screen titles

Medium card titles

Small muted metadata (date, role, graduation year, etc.)

21.4 Components to Standardize

Feed Card

Rounded rectangle

Thumbnail on left

Title + metadata on right

Tappable row

Segmented Control Tabs

Used in Discovery, Bounties, News

Bottom Tab Bar

Simple icons + short labels

Detail Page Layout

Back button top-left

Action icons top-right (share/save/overflow pattern)

Large title

Metadata row beneath (author/class/date/read time equivalent)

Primary content section below

21.5 “Key Points” Callout Pattern (From the article view)

In bounty detail and news detail screens, include an optional callout box styled like the screenshot’s “Key Points” area:

Light background panel

Thin colored accent line on the left

Bullet points inside
Use cases:

Bounty “Quick Summary”

“How to help / expectations”

News post highlights

21.6 Interaction Feel

Smooth scrolling

Tap anywhere on a card row to open details

Secondary actions are tucked into:

a small “…” menu on list items, or

top-right icon buttons on detail screens