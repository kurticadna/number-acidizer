# NUMBER ACIDIZER

This project is designed to manage a shared global counter through a web interface. The system consists of a REST API backend and a React-based frontend. The backend is responsible for receiving, storing, and managing counter operations (increment/decrement) with ACID guarantees, while the frontend allows users to interact with the counter and see real-time updates across multiple devices and browser tabs.

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

## Project structure

```
number-acidizer/
├── backend/           # Lambda function code
├── frontend/          # React/Next.js application
├── infrastructure/    # Terraform configuration
├── .github/workflows/ # CI/CD pipeline
└── README.md         # This file
```

