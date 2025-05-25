import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const TABLE_NAME = process.env.DYNAMODB_TABLE_NAME || 'acidizer-counter';
const COUNTER_ID = 'global-counter';

interface RequestBody {
  action: 'increment' | 'decrement';
}

interface ApiResponse {
  success: boolean;
  value?: number;
  error?: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  'Content-Type': 'application/json'
} as const;

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    if (event.httpMethod === 'OPTIONS') {
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: ''
      };
    }
    // GET: Return current value
    if (event.httpMethod === 'GET') {
      const result = await docClient.send(new GetCommand({
        TableName: TABLE_NAME,
        Key: { id: COUNTER_ID }
      }));

      const response: ApiResponse = {
        success: true,
        value: result.Item?.value || 0
      };

      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify(response)
      };
    }

    // POST: Increment or decrement
    if (event.httpMethod === 'POST') {
      // Input validation
      if (!event.body) {
        const response: ApiResponse = { success: false, error: 'Request body required' };
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify(response)
        };
      }

      let requestBody: RequestBody;
      try {
        const parsed = JSON.parse(event.body) as unknown;

        if (!isValidRequestBody(parsed)) {
          const response: ApiResponse = { success: false, error: 'Invalid action. Use increment or decrement' };
          return {
            statusCode: 400,
            headers: corsHeaders,
            body: JSON.stringify(response)
          };
        }

        requestBody = parsed;
      } catch {
        const response: ApiResponse = { success: false, error: 'Invalid JSON' };
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify(response)
        };
      }

      const { action } = requestBody;

      if (action === 'increment') {
        try {
          // FIXED: Use atomic ADD operation with proper boundary check
          const result = await docClient.send(new UpdateCommand({
            TableName: TABLE_NAME,
            Key: { id: COUNTER_ID },
            UpdateExpression: 'ADD #value :increment',
            ConditionExpression: 'attribute_not_exists(#value) OR #value < :max',
            ExpressionAttributeNames: { '#value': 'value' },
            ExpressionAttributeValues: {
              ':increment': 1,
              ':max': 1000000000
            },
            ReturnValues: 'ALL_NEW'
          }));

          const response: ApiResponse = {
            success: true,
            value: result.Attributes?.value as number
          };

          return {
            statusCode: 200,
            headers: corsHeaders,
            body: JSON.stringify(response)
          };
        } catch (error: unknown) {
          if (isConditionalCheckError(error)) {
            const response: ApiResponse = { success: false, error: 'Cannot exceed 1 billion' };
            return {
              statusCode: 400,
              headers: corsHeaders,
              body: JSON.stringify(response)
            };
          }
          throw error;
        }
      }

      if (action === 'decrement') {
        try {
          const result = await docClient.send(new UpdateCommand({
            TableName: TABLE_NAME,
            Key: { id: COUNTER_ID },
            UpdateExpression: 'ADD #value :decrement',
            ConditionExpression: 'attribute_exists(#value) AND #value > :min',
            ExpressionAttributeNames: { '#value': 'value' },
            ExpressionAttributeValues: {
              ':decrement': -1,
              ':min': 0
            },
            ReturnValues: 'ALL_NEW'
          }));

          const response: ApiResponse = {
            success: true,
            value: result.Attributes?.value as number
          };

          return {
            statusCode: 200,
            headers: corsHeaders,
            body: JSON.stringify(response)
          };
        } catch (error: unknown) {
          if (isConditionalCheckError(error)) {
            const response: ApiResponse = { success: false, error: 'Cannot go below 0' };
            return {
              statusCode: 400,
              headers: corsHeaders,
              body: JSON.stringify(response)
            };
          }
          throw error;
        }
      }
    }

    const response: ApiResponse = { success: false, error: 'Method not allowed' };
    return {
      statusCode: 405,
      headers: corsHeaders,
      body: JSON.stringify(response)
    };

  } catch (error: unknown) {
    console.error('Handler error:', error);
    const response: ApiResponse = { success: false, error: 'Internal server error' };
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify(response)
    };
  }
};

// Type guard functions
function isValidRequestBody(obj: unknown): obj is RequestBody {
  return (
    typeof obj === 'object' &&
    obj !== null &&
    'action' in obj &&
    (obj.action === 'increment' || obj.action === 'decrement')
  );
}

function isConditionalCheckError(error: unknown): boolean {
  return (
    error instanceof Error &&
    error.name === 'ConditionalCheckFailedException'
  );
}