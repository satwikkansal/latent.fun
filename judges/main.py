from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import APIKeyHeader
from pydantic import BaseModel
from aptos_sdk.account import Account
from aptos_sdk.client import RestClient
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = FastAPI()

# Security configuration
API_KEY_NAME = "X-API-Key"
API_KEY = os.getenv("API_KEY")
api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=True)

# Configuration
NODE_URL = os.getenv("APTOS_NODE_URL", "https://fullnode.devnet.aptoslabs.com/v1")
MODULE_ADDRESS = os.getenv("MODULE_ADDRESS")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Specify your frontend URL in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Store judge private keys securely (in production, use a proper secure storage solution)
JUDGE_KEYS = {
    "judge1": os.getenv("JUDGE1_PRIVATE_KEY"),
    "judge2": os.getenv("JUDGE2_PRIVATE_KEY"),
    # Add more judges as needed
}


class JudgeScoreRequest(BaseModel):
    judge_id: str  # Instead of private key, use judge ID
    performance_id: int
    score: int


async def verify_api_key(api_key: str = Depends(api_key_header)):
    if api_key != API_KEY:
        raise HTTPException(
            status_code=403,
            detail="Invalid API key"
        )
    return api_key


@app.post("/submit-judge-score")
async def submit_judge_score(
        request: JudgeScoreRequest,
        api_key: str = Depends(verify_api_key)
):
    try:
        # Get judge private key from secure storage
        judge_private_key = JUDGE_KEYS.get(request.judge_id)
        if not judge_private_key:
            raise HTTPException(
                status_code=400,
                detail="Invalid judge ID"
            )

        # Initialize REST client
        rest_client = RestClient(NODE_URL)

        # Create judge account
        judge_account = Account.load_key(bytes.fromhex(judge_private_key))

        # Validate score range
        if not 0 <= request.score <= 10:
            raise HTTPException(
                status_code=400,
                detail="Score must be between 0 and 10"
            )

        # Prepare transaction payload
        payload = {
            "function": f"{MODULE_ADDRESS}::talent_show::submit_judge_score",
            "type_arguments": [],
            "arguments": [
                str(request.performance_id),
                str(request.score)
            ]
        }

        # Submit transaction
        signed_transaction = await rest_client.submit_transaction(
            judge_account,
            payload
        )

        # Wait for transaction
        await rest_client.wait_for_transaction(signed_transaction)

        return {
            "status": "success",
            "message": "Judge score submitted successfully",
            "transaction_hash": signed_transaction
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Server error: {str(e)}"
        )


@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "node_url": NODE_URL,
        "module_address": MODULE_ADDRESS
    }

if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", debug=True)
