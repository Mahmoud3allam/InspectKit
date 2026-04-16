Design a polished iOS debug tool UI for an in-app “Network Inspector”.

Platform:
- iPhone app
- modern iOS visual language
- dark mode first
- suitable for developers and QA
- compact, information-dense, but clean and readable

Goal:
Create the UI for a rich real-time network monitoring screen embedded inside an app for lower environments.

Main screens to design:

1. Floating entry point
- small draggable debug bubble
- subtle dev-tool styling
- expandable on tap
- should feel non-intrusive

2. Network dashboard / request list
Show a live-updating list of requests with:
- HTTP method badge
- endpoint path
- host/domain
- status code badge
- success/failure indicator
- duration
- timestamp
- request/response size summary
- optional “in progress” animated state

Top controls:
- search bar
- segmented filters for All / Success / Failed / In Progress
- method filter chips: GET POST PUT PATCH DELETE
- sort: newest first
- clear button
- compact summary cards at top:
  - total requests
  - failures
  - average duration
  - active requests

3. Request detail screen
Create a rich tabbed detail page with tabs:
- Overview
- Request
- Response
- Headers
- Metrics
- cURL

Overview tab:
- full URL
- method
- status
- start time
- total duration
- request size
- response size
- environment label
- error card if failed

Request tab:
- headers section
- body section
- pretty JSON card when body is JSON
- raw text fallback
- redacted secrets visual style

Response tab:
- response headers
- formatted body
- empty-state for no body
- binary/file response metadata card

Headers tab:
- clean key/value rows
- grouped request vs response headers
- copy affordance

Metrics tab:
- timeline visualization for:
  - DNS
  - Connect
  - TLS
  - Request sent
  - First byte
  - Response receive
- show total duration prominently
- show transport metadata such as protocol and connection reuse

cURL tab:
- code block style card
- copy button
- export/share button

Visual direction:
- native iOS feel
- rounded cards
- thin separators
- dense but elegant spacing
- clear hierarchy
- small badges for method and status
- color-coded success/warning/error states
- sticky top bar
- scrollable detail content
- large payloads shown in expandable sections

Components needed:
- badges
- chips
- summary cards
- searchable list items
- segmented control
- tab bar
- JSON/code viewer style panels
- timeline row visualization
- empty states
- error states

Important UX details:
- prioritize readability over decoration
- make long URLs and JSON manageable
- let failed requests stand out clearly
- let active requests feel live
- support developer workflows
- design should feel like a premium internal debugging tool

Output:
- mobile app UI screens
- component set for reuse
- dark theme
- include one list screen and one detailed request screen