import os
import json
from groq import Groq
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# 1. Initialize the client.
# (It will look for an environment variable named GROQ_API_KEY)
client = Groq(api_key=os.environ.get("GROQ_API_KEY"))

# The silently highlighted vocabulary word from River Reader
test_word = "meticulous"

# 2. Craft a structured prompt for "Context Clash"
prompt = f"""
Generate data for the game 'Context Clash' using the word '{test_word}'. 
Target audience: Casual intermediate English readers.

You must return a JSON object with exactly these keys:
- "word": The target word.
- "definition": A simple, casual explanation of the word.
- "correct_sentence": A natural sentence using the word properly.
- "clash_sentence": A tricky sentence using the word INCORRECTLY in a way that sounds plausible but makes no logical sense.
- "explanation": A brief, friendly note explaining why the clash sentence is wrong.

Return ONLY raw JSON. No markdown, no formatting backticks like ```json.
"""

print(f"📡 Sending '{test_word}' to Groq (llama-3.1-8b-instant)...")

try:
    # 3. Create the chat completion request
    completion = client.chat.completions.create(
        model="llama-3.1-8b-instant",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.8,  # Slightly creative for varied gameplay
        # Enforce strict JSON output from the model
        response_format={"type": "json_object"} 
    )
    
    # 4. Extract and print the string result
    raw_json_output = completion.choices[0].message.content
    print("\n✅ Success! Received Output:\n")
    print(raw_json_output)
    
    # Verify it can be loaded directly as a Python dictionary (perfect for SQLite)
    parsed_data = json.loads(raw_json_output)
    
except Exception as e:
    print(f"\n❌ Error occurred: {e}")
    print("Make sure you ran 'export GROQ_API_KEY=your_key_here' in your terminal before running this script.")