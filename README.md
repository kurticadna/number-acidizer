# NUMBER ACIDIZER

This project is designed to manage a shared global counter through a web interface. The system consists of a REST API backend and a React-based frontend. The backend is responsible for receiving, storing, and managing counter operations (increment/decrement) with ACID guarantees, while the frontend allows users to interact with the counter and see real-time updates across multiple devices and browser tabs.

## Project structure

```
number-acidizer/
├── backend/           # Lambda function code
├── frontend/          # React/Next.js application
├── infrastructure/    # Terraform configuration
├── .github/workflows/ # CI/CD pipeline
└── README.md         # This file
```

## Project Overview

This project is a single-page application built with a modern technology stack, including React.js for the frontend, Next.js with TypeScript for static site generation, Zustand for state management, AWS Lambda for serverless backend functions, DynamoDB for data persistence, and API Gateway for REST API management.
The application is designed to handle concurrent counter operations with ACID compliance, real-time synchronization across devices, and abuse protection through rate limiting.

## Features

- Counter Operations: Users can increment or decrement a shared global counter through intuitive button controls.
- Real-time Synchronization: Counter updates are automatically synchronized across multiple devices and browser tabs without manual refresh.
- ACID Compliance: All counter operations maintain data integrity through atomic DynamoDB operations with proper race condition handling.
- Abuse Protection: Rate limiting (10 requests/second) prevents automated abuse while allowing normal user interactions.
- Responsive Design: Clean, modern interface built with Tailwind CSS that works seamlessly across desktop and mobile devices.
- Error Handling: Graceful error recovery with clear user feedback for network issues or API failures.
- Boundary Enforcement: Counter is safely constrained between 0 and 1 billion with proper validation.
- Animation Effects: Smooth number transitions provide visual feedback for counter changes.

This project leverages AWS Lambda for serverless backend functions, DynamoDB for reliable data persistence, and API Gateway for REST API management with built-in throttling.

## Git Management

Branching Strategy: The project uses two primary branches: main and dev.

dev Branch: This branch is used for active development. All new features, bug fixes, and changes are implemented and tested here before being merged into the main branch.

main Branch: The main branch represents the stable production version of the project. Only code that has been fully tested and verified in the dev branch is merged into main.

## Authorization solution

I'd recommend AWS Cognito with Google social login for the counter website users. The approach balances complexity well because users just click "Sign in with Google" once, no passwords or forms to fill out, while anonymous users can still use the counter without any friction. For granularity, anonymous users would keep the current 10 requests/sec limit, but signed-in users could get 100 requests, which is meaningful for people who want to use the counter frequently.

Implementation-wise, it's really straightforward because Cognito integrates directly with API Gateway, so my Lambda function just receives a user ID when someone is logged in - no complex session management or custom authentication flows to build. 

## ACID Tests


- Lost operations: Counter doesn't increase by exact number of requests
- Race conditions: Inconsistent results across multiple test runs
- Boundary violations: Counter goes below 0 or above 1 billion

Here are some of the ACID compliance tests I've been running from my terminal:

### Test 1: Concurrent increments
 Expected: All requests succeed, counter increases by exact number of requests
```
for i in {1..100}; do
  curl -X POST $API_URL -d '{"action":"increment"}' &
done
wait
```
Verify: Counter increased by exactly 100

### Test 2: Mixed concurrent operations
```for i in {1..50}; do
  curl -X POST $API_URL -d '{"action":"increment"}' &
  curl -X POST $API_URL -d '{"action":"decrement"}' &
done
wait
```
Verify: Net change is 0

### Test 3: Boundary race conditions
 Set counter to 1, then try 10 concurrent decrements
 Expected: Only 1 succeeds, others fail gracefully
Boundary Condition Tests

```curl -X POST $API_URL -d '{"action":"decrement"}' # 
when count = 0
```
Expected: Error, count stays 0

### Test 4: Burst requests

```for i in {1..100}; do
  curl -X POST $API_URL -d '{"action":"increment"}'
done
```
Expected: Some requests get 429 (rate limited)

### Test 5: Invalid action
```curl -X POST $API_URL -d '{"action":"incrementtt"' ```
Expected: 400 Bad Request

### Test 6: Cross-Tab Sync Tests
- Open 5 tabs, click increment in tab 1
- Verify: All tabs show updated number within 7 seconds

- Test multiple rapid clicks across tabs
- Verify: Each click registers exactly once

