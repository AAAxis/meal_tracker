# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

from firebase_functions import https_fn
from firebase_admin import initialize_app
import json
import time
import stripe
import os

# Initialize Firebase app
app = initialize_app()

# Initialize Stripe with your secret key from environment variable
# For Firebase Functions, you can also use: functions_config.get('stripe.secret_key')
stripe_key = os.environ.get('STRIPE_SECRET_KEY')
if not stripe_key:
    raise ValueError("STRIPE_SECRET_KEY environment variable is required")
stripe.api_key = stripe_key
print(f"🔑 Stripe API key configured: {stripe_key[:12]}...")

# Import our custom helper module
from openai_helper import analyze_image_with_vision

# OpenAI function for analyzing meal images
@https_fn.on_request()
def analyze_meal_image(req: https_fn.Request) -> https_fn.Response:
    """Analyze meal image using OpenAI Vision API"""
    try:
        # Get data from request
        data = req.get_json()
        image_url = data.get('image_url')
        image_base64 = data.get('image_base64')
        image_name = data.get('image_name', 'unknown.jpg')
        function_info = data.get('function_info', {})
        
        print(f"Received analysis request for image: {image_name}")
        
        if image_url:
            print(f"Image URL length: {len(image_url)}")
        if image_base64:
            print(f"Image base64 length: {len(image_base64)}")
        
        # Validate that we have either URL or base64
        if not image_url and not image_base64:
            return https_fn.Response(
                json.dumps({'error': 'Either image_url or image_base64 must be provided'}),
                status=400,
                headers={'Content-Type': 'application/json'}
            )
            
        # Validate URL format if provided
        if image_url and not image_url.startswith(('http://', 'https://')):
            return https_fn.Response(
                json.dumps({'error': 'Invalid image URL format. Must start with http:// or https://'}),
                status=400,
                headers={'Content-Type': 'application/json'}
            )

        if image_url:
            print(f"Processing image URL: {image_url[:50]}...")
        else:
            print(f"Processing base64 image data ({len(image_base64)} characters)")
        
        prompt = """
Analyze this meal image and provide detailed nutritional information in JSON format. Include:
1. Meal identification
2. Accurate calorie estimation
3. Detailed macro breakdown (in grams)
4. List of ingredients
5. A categorical healthiness value (e.g., 'healthy', 'medium', 'unhealthy')
6. Detailed health assessment text
7. Source URL for more information

Additionally, return the meal name and the list of ingredients in three languages: English, Hebrew, and Russian.

Format the response as:
{
  'mealName': {'en': '...', 'he': '...', 'ru': '...'},
  'estimatedCalories': number (e.g., 670),
  'macros': {
    'proteins': 'Xg (e.g., 30g)',
    'carbohydrates': 'Xg (e.g., 50g)',
    'fats': 'Xg (e.g., 40g)'
  },
  'ingredients': {
    'en': ['...', '...'],
    'he': ['...', '...'],
    'ru': ['...', '...']
  },
  'healthiness': 'healthy' | 'medium' | 'unhealthy' | 'N/A',
  'health_assessment': 'Detailed health assessment of the meal',
  'source': 'A valid URL (starting with http or https) for more information about this meal'
}

Important:
- Provide realistic calorie and macro values based on visible portions.
- Ensure 'estimatedCalories' is a number.
- Ensure macros (proteins, carbohydrates, fats) are strings ending with 'g'.
- The 'healthiness' field should be one of 'healthy', 'medium', 'unhealthy', or 'N/A'.
- Provide a comprehensive 'health_assessment' string.
- The source field MUST be a valid URL, defaulting to https://fdc.nal.usda.gov/ if needed.
- All translations must be accurate and contextually appropriate for food.
"""

        try:
            # Using the custom analyze_image_with_vision function from openai_helper
            raw_analysis_output = analyze_image_with_vision(
                image_url=image_url, 
                prompt=prompt, 
                image_base64=image_base64
            )
            
            # Debug: Log what OpenAI actually returned
            print(f"🔍 Raw OpenAI output type: {type(raw_analysis_output)}")
            if isinstance(raw_analysis_output, str):
                print(f"🔍 Raw OpenAI output (first 500 chars): {raw_analysis_output[:500]}")
            else:
                print(f"🔍 Raw OpenAI output: {raw_analysis_output}")
            
            final_json_payload_str: str

            if isinstance(raw_analysis_output, str):
                text_to_parse = raw_analysis_output.strip()

                # Try to remove markdown fences
                if text_to_parse.startswith("```json") and text_to_parse.endswith("```"):
                    # Slice from after "```json" (length 7) to before "```" (length 3 from end)
                    text_to_parse = text_to_parse[len("```json"):-len("```")].strip()
                elif text_to_parse.startswith("```") and text_to_parse.endswith("```"):
                    # Slice from after "```" (length 3) to before "```" (length 3 from end)
                    text_to_parse = text_to_parse[len("```"):-len("```")].strip()

                # After attempting to strip markdown, find the JSON object
                json_start_index = text_to_parse.find('{')
                json_end_index = text_to_parse.rfind('}')

                if json_start_index != -1 and json_end_index != -1 and json_end_index > json_start_index:
                    json_str_candidate = text_to_parse[json_start_index : json_end_index + 1]
                    try:
                        parsed_json = json.loads(json_str_candidate)
                        
                        # Debug: Check if healthiness is in the parsed JSON
                        print(f"🔍 Parsed JSON keys: {list(parsed_json.keys())}")
                        if 'healthiness' in parsed_json:
                            print(f"✅ Found healthiness in parsed JSON: {parsed_json['healthiness']}")
                        else:
                            print("❌ No healthiness field found in parsed JSON")
                            print(f"🔍 Full parsed JSON: {parsed_json}")
                            # Add default healthiness if missing
                            parsed_json['healthiness'] = 'N/A'
                            print("🔧 Added default healthiness: N/A")
                        
                        final_json_payload_str = json.dumps(parsed_json) # Re-serialize for clean output
                    except json.JSONDecodeError as e:
                        error_message = f"Could not parse extracted JSON (from braces) from vision API output. Error: {str(e)}. Candidate snippet: {json_str_candidate[:200]}"
                        print(error_message)
                        raise Exception(error_message) from e
                else:
                    # If no '{...}' found, try to parse the text_to_parse directly
                    try:
                        parsed_json = json.loads(text_to_parse)
                        
                        # Debug: Check if healthiness is in the parsed JSON
                        print(f"🔍 Direct parse JSON keys: {list(parsed_json.keys())}")
                        if 'healthiness' in parsed_json:
                            print(f"✅ Found healthiness in direct parsed JSON: {parsed_json['healthiness']}")
                        else:
                            print("❌ No healthiness field found in direct parsed JSON")
                            print(f"🔍 Full direct parsed JSON: {parsed_json}")
                            # Add default healthiness if missing
                            parsed_json['healthiness'] = 'N/A'
                            print("🔧 Added default healthiness: N/A")
                        
                        final_json_payload_str = json.dumps(parsed_json) 
                    except json.JSONDecodeError as e:
                        error_message = f"Vision API output is not a recognized JSON object (no braces found) and not a simple JSON string after stripping. Error: {str(e)}. Output snippet: {text_to_parse[:200]}"
                        print(error_message)
                        raise Exception(error_message) from e
            elif isinstance(raw_analysis_output, (dict, list)):
                final_json_payload_str = json.dumps(raw_analysis_output)
            else:
                error_message = f"Unexpected data type from image analysis service: {type(raw_analysis_output)}. Output snippet: {str(raw_analysis_output)[:200]}"
                print(error_message)
                raise Exception(error_message)

            # Return the cleaned and validated analysis result
            return https_fn.Response(
                final_json_payload_str,
                status=200,
                headers={'Content-Type': 'application/json'}
            )
        except Exception as vision_error:
            print(f"OpenAI Vision API error: {str(vision_error)}")
            # Return a more helpful error message
            error_response = {
                "error": "Failed to analyze image with OpenAI Vision API",
                "message": str(vision_error),
                "fallback_analysis": {
                    "meal_name": "Unknown meal (analysis failed)",
                    "estimated_calories": 0,
                    "macronutrients": {
                        "proteins": "0g",
                        "carbohydrates": "0g",
                        "fats": "0g"
                    },
                    "ingredients": ["could not analyze image"],
                    "health_assessment": "Analysis failed. Please try again later.",
                    "source": "https://fdc.nal.usda.gov/"
                }
            }
            return https_fn.Response(
                json.dumps(error_response),
                status=200,  # Return 200 with error info instead of 500
                headers={'Content-Type': 'application/json'}
            )
        
    except Exception as e:
        print(f"Error in analyze_meal_image: {str(e)}")
        return https_fn.Response(
            json.dumps({
                "error": "General error occurred",
                "message": str(e),
                "fallback_analysis": {
                    "meal_name": "Error occurred",
                    "estimated_calories": 0,
                    "macronutrients": {
                        "proteins": "0g",
                        "carbohydrates": "0g",
                        "fats": "0g"
                    },
                    "ingredients": ["analysis failed"],
                    "health_assessment": "Error occurred during analysis.",
                    "source": "https://fdc.nal.usda.gov/"
                }
            }),
            status=200,
            headers={'Content-Type': 'application/json'}
        )

# Simple Stripe payment function (from backend.txt)
@https_fn.on_call()
def create_payment_intent(req: https_fn.CallableRequest) -> any:
    """Create a Stripe payment intent - simple version"""
    try:
        # Extract amount and currency from the request
        data = req.data
        print(f"🔍 Request data: {data}")
        
        amount = data.get('amount')
        currency = data.get('currency', 'usd')  # Default to 'usd' if not provided
        
        print(f"Creating payment intent: amount={amount}, currency={currency}")
        
        # Validate amount
        print(f"🔍 Amount validation: amount={amount}, type={type(amount)}")
        if amount is None:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                message=f'Amount is missing from request. Received data: {data}'
            )
        
        # Convert to int if it's a string or float
        try:
            amount_int = int(float(amount))
            print(f"🔍 Converted amount: {amount_int}")
        except (ValueError, TypeError) as e:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                message=f'Invalid amount format: {amount}. Error: {str(e)}'
            )
        
        if amount_int <= 0:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                message=f'Invalid amount: {amount_int}. Amount must be a positive number.'
            )
        
        # Create a PaymentIntent with automatic payment methods (includes cards, Apple Pay, Google Pay)
        try:
            print(f"🔍 About to create Stripe PaymentIntent with amount={amount_int}, currency={currency}")
            payment_intent = stripe.PaymentIntent.create(
                amount=amount_int,
                currency=currency,
                automatic_payment_methods={
                    'enabled': True,
                },
            )
            
            print(f"✅ Payment intent created successfully: {payment_intent.id}")
            
            # Return the client secret - this will be wrapped in a 'data' field automatically
            return {'clientSecret': payment_intent['client_secret']}
            
        except stripe.error.StripeError as stripe_error:
            print(f"❌ Stripe error: {str(stripe_error)}")
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INTERNAL,
                message=f'Stripe error: {str(stripe_error)}'
            )
        
    except https_fn.HttpsError:
        # Re-raise HttpsError as-is
        raise
    except Exception as e:
        print(f"❌ General error: {str(e)}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f'Server error: {str(e)}'
        )
