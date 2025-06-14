import os
import json
import requests
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Get API key from environment variables
api_key = os.environ.get("OPENAI_API_KEY", "")

if api_key and len(api_key) > 10:
    print("🔑 OpenAI API key loaded successfully")
else:
    print("❌ OpenAI API key not configured or invalid")
    print("📝 Please set OPENAI_API_KEY in your .env file")
    print("📝 Get your key from: https://platform.openai.com/api-keys")

def analyze_image_with_vision(image_url=None, prompt=None, image_base64=None):
    """
    Analyze an image using OpenAI's Vision capabilities
    
    Args:
        image_url (str, optional): URL of the image to analyze
        prompt (str): Instructions for the analysis
        image_base64 (str, optional): Base64 encoded image data
        
    Returns:
        str or dict: The analysis result from OpenAI
    """
    try:
        print(f"🔍 Starting OpenAI Vision API call...")
        print(f"🔍 API key configured: {'Yes' if api_key and len(api_key) > 10 else 'No/Invalid'}")
        print(f"🔍 API key length: {len(api_key) if api_key else 0}")
        
        if image_url:
            print(f"🔍 Image URL: {image_url[:100]}..." if len(image_url) > 100 else f"🔍 Image URL: {image_url}")
        if image_base64:
            print(f"🔍 Image base64: {len(image_base64)} characters")
        
        if not api_key:
            error_msg = "OpenAI API key not configured in environment variables"
            print(f"❌ {error_msg}")
            return {"error": error_msg}
        
        if len(api_key) < 20:  # OpenAI keys are typically much longer
            error_msg = f"OpenAI API key appears to be invalid (too short: {len(api_key)} characters)"
            print(f"❌ {error_msg}")
            return {"error": error_msg}
        
        # Validate image input
        if not image_url and not image_base64:
            error_msg = "Either image_url or image_base64 must be provided"
            print(f"❌ {error_msg}")
            return {"error": error_msg}
        
        if image_url and not image_url.startswith(('http://', 'https://')):
            error_msg = f"Invalid image URL format: {image_url}"
            print(f"❌ {error_msg}")
            return {"error": error_msg}
        
        # Manually construct the API request instead of using the client library
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}"
        }
        
        # Prepare image content based on input type
        if image_base64:
            image_content = {
                "type": "image_url",
                "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}
            }
            print(f"🔍 Using base64 image data")
        else:
            image_content = {
                "type": "image_url",
                "image_url": {"url": image_url}
            }
            print(f"🔍 Using image URL")

        payload = {
            "model": "gpt-4o-mini",
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        image_content
                    ]
                }
            ],
            "max_tokens": 1000
        }
        
        print(f"🚀 Making OpenAI API request...")
        print(f"🚀 Model: {payload['model']}")
        print(f"🚀 Max tokens: {payload['max_tokens']}")
        
        response = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers=headers,
            json=payload,
            timeout=30  # Add timeout
        )
        
        print(f"📥 OpenAI API response status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ OpenAI API call successful")
            if "choices" in result and len(result["choices"]) > 0:
                content = result["choices"][0]["message"]["content"]
                print(f"✅ Got content from OpenAI (length: {len(content)})")
                return content
            else:
                error_msg = "No content in OpenAI response"
                print(f"❌ {error_msg}")
                print(f"❌ Full response: {result}")
                return {"error": error_msg}
        else:
            error_msg = f"OpenAI API call failed with status {response.status_code}"
            print(f"❌ {error_msg}")
            print(f"❌ Response text: {response.text}")
            
            # Parse common OpenAI errors
            try:
                error_data = response.json()
                if "error" in error_data:
                    openai_error = error_data["error"]
                    if isinstance(openai_error, dict):
                        error_type = openai_error.get("type", "unknown")
                        error_message = openai_error.get("message", "Unknown error")
                        error_code = openai_error.get("code", "unknown")
                        
                        print(f"❌ OpenAI Error Type: {error_type}")
                        print(f"❌ OpenAI Error Message: {error_message}")
                        print(f"❌ OpenAI Error Code: {error_code}")
                        
                        return {"error": f"OpenAI API Error ({error_type}): {error_message}"}
            except:
                pass
            
            return {"error": f"API call failed with status {response.status_code}: {response.text[:200]}"}
        
    except requests.exceptions.Timeout:
        error_msg = "OpenAI API request timed out after 30 seconds"
        print(f"❌ {error_msg}")
        return {"error": error_msg}
    except requests.exceptions.ConnectionError:
        error_msg = "Failed to connect to OpenAI API - network connection error"
        print(f"❌ {error_msg}")
        return {"error": error_msg}
    except Exception as e:
        error_msg = f"Unexpected error in OpenAI Vision API call: {str(e)}"
        print(f"❌ {error_msg}")
        print(f"❌ Error type: {type(e).__name__}")
        return {"error": error_msg} 