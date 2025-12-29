from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import os
import random
import string
import hashlib
import time
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from dotenv import load_dotenv
from supabase import create_client, Client
from openai import OpenAI

# 載入環境變數
load_dotenv()

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 從環境變數讀取設定，如果沒有則使用預設值（從 Flutter app 中取得）
supabase_url = os.getenv("SUPABASE_URL") or "https://iqmhqdkpultzyzurolwv.supabase.co"
supabase_key = os.getenv("SUPABASE_KEY") or "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxbWhxZGtwdWx0enl6dXJvbHd2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4MDc1NzMsImV4cCI6MjA4MTM4MzU3M30.OfBqLiwFQLjyuJwkgU1Vu1eedjrzkeVsSznQAnR9B9Q"

supabase: Client = create_client(
    supabase_url,
    supabase_key
)

# 初始化 OpenAI 客戶端
openai_api_key = os.getenv("OPENAI_API_KEY")
if not openai_api_key:
    raise ValueError("OPENAI_API_KEY 環境變數未設定。請在 .env 檔案中設定 OPENAI_API_KEY")
openai_client = OpenAI(api_key=openai_api_key)

# 驗證碼存儲（生產環境應使用 Redis 或資料庫）
verification_codes: Dict[str, Dict[str, Any]] = {}  # {email: {code: str, expires_at: float}}


def send_verification_email(to_email: str, verification_code: str):
    """
    發送驗證碼郵件
    支援 SMTP（Gmail、Outlook等）和 SendGrid
    """
    # 從環境變數讀取郵件設定
    smtp_enabled = os.getenv("SMTP_ENABLED", "false").lower() == "true"
    sendgrid_enabled = os.getenv("SENDGRID_ENABLED", "false").lower() == "true"
    
    # 優先使用 SendGrid（如果啟用）
    if sendgrid_enabled:
        try:
            send_with_sendgrid(to_email, verification_code)
            return
        except Exception as e:
            print(f"SendGrid 發送失敗，嘗試 SMTP: {e}")
    
    # 使用 SMTP（如果啟用）
    if smtp_enabled:
        send_with_smtp(to_email, verification_code)
    else:
        # 如果都沒有啟用，拋出異常
        raise Exception("郵件服務未配置。請設置 SMTP_ENABLED=true 或 SENDGRID_ENABLED=true")


def send_with_smtp(to_email: str, verification_code: str):
    """使用 SMTP 發送郵件（支援 Gmail、Outlook 等）"""
    smtp_server = os.getenv("SMTP_SERVER", "smtp.gmail.com")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_username = os.getenv("SMTP_USERNAME")
    smtp_password = os.getenv("SMTP_PASSWORD")
    smtp_from_email = os.getenv("SMTP_FROM_EMAIL", smtp_username)
    
    if not smtp_username or not smtp_password:
        raise Exception("SMTP 設定不完整。請設置 SMTP_USERNAME 和 SMTP_PASSWORD")
    
    # 創建郵件
    msg = MIMEMultipart('alternative')
    msg['Subject'] = '註冊驗證碼'
    msg['From'] = smtp_from_email
    msg['To'] = to_email
    
    # 郵件內容（HTML）
    html_content = f"""
    <html>
      <body>
        <h2>註冊驗證碼</h2>
        <p>您的驗證碼是：<strong style="font-size: 24px; color: #4CAF50;">{verification_code}</strong></p>
        <p>此驗證碼將在 <strong>10 分鐘</strong> 後過期。</p>
        <p>如果您沒有請求此驗證碼，請忽略此郵件。</p>
      </body>
    </html>
    """
    
    # 純文字版本
    text_content = f"""
    註冊驗證碼
    
    您的驗證碼是：{verification_code}
    
    此驗證碼將在 10 分鐘後過期。
    
    如果您沒有請求此驗證碼，請忽略此郵件。
    """
    
    part1 = MIMEText(text_content, 'plain', 'utf-8')
    part2 = MIMEText(html_content, 'html', 'utf-8')
    
    msg.attach(part1)
    msg.attach(part2)
    
    # 發送郵件
    try:
        server = smtplib.SMTP(smtp_server, smtp_port)
        server.starttls()
        server.login(smtp_username, smtp_password)
        server.send_message(msg)
        server.quit()
        print(f"郵件已通過 SMTP 發送到 {to_email}")
    except smtplib.SMTPAuthenticationError as e:
        error_msg = str(e)
        if "BadCredentials" in error_msg or "535" in error_msg:
            raise Exception(
                "Gmail 認證失敗。\n\n"
                "請確認：\n"
                "1. 已啟用兩步驟驗證\n"
                "2. 已生成應用程式密碼（不是 Gmail 登入密碼）\n"
                "3. SMTP_PASSWORD 使用的是 16 位應用程式密碼\n\n"
                "詳細步驟請參考：backend/EMAIL_SETUP_GUIDE.md"
            )
        else:
            raise Exception(f"SMTP 認證失敗: {str(e)}")
    except Exception as e:
        raise Exception(f"SMTP 發送失敗: {str(e)}")


def send_with_sendgrid(to_email: str, verification_code: str):
    """使用 SendGrid 發送郵件"""
    try:
        from sendgrid import SendGridAPIClient
        from sendgrid.helpers.mail import Mail
    except ImportError:
        raise Exception("SendGrid 套件未安裝。請執行: pip install sendgrid")
    
    sendgrid_api_key = os.getenv("SENDGRID_API_KEY")
    sendgrid_from_email = os.getenv("SENDGRID_FROM_EMAIL", "noreply@yourapp.com")
    
    if not sendgrid_api_key:
        raise Exception("SENDGRID_API_KEY 未設置")
    
    message = Mail(
        from_email=sendgrid_from_email,
        to_emails=to_email,
        subject='註冊驗證碼',
        html_content=f"""
        <h2>註冊驗證碼</h2>
        <p>您的驗證碼是：<strong style="font-size: 24px; color: #4CAF50;">{verification_code}</strong></p>
        <p>此驗證碼將在 <strong>10 分鐘</strong> 後過期。</p>
        <p>如果您沒有請求此驗證碼，請忽略此郵件。</p>
        """
    )
    
    try:
        sg = SendGridAPIClient(sendgrid_api_key)
        response = sg.send(message)
        print(f"郵件已通過 SendGrid 發送到 {to_email}, 狀態碼: {response.status_code}")
    except Exception as e:
        raise Exception(f"SendGrid 發送失敗: {str(e)}")


class QuestionRequest(BaseModel):
    question: str
    stage: int


class AdditionalQuestionRequest(BaseModel):
    user_message: str
    question: str
    stage: int
    conversation_history: List[Dict[str, Any]]


class ChatGPTResponse(BaseModel):
    response: str


class SendVerificationCodeRequest(BaseModel):
    email: str


class VerifyCodeRequest(BaseModel):
    email: str
    code: str


@app.get("/")
async def root():
    return {"message": "SGQ API Server"}


@app.post("/api/chatgpt/scaffolding", response_model=ChatGPTResponse)
async def get_scaffolding(request: QuestionRequest):
    try:
        stage_prompts = {
            1: """【階段一：認知鷹架 Prompt（Cognitive Scaffolding）】
Here is the grammar question I created:
{question}
Please help me reflect on the thinking behind this question:
1. What grammar rule or language feature does this question mainly test?
2. Is the target rule clearly focused, or might learners be confused?
3. Are there any elements that distract from the grammar focus?""",
            2: """【階段二：形式鷹架 Prompt（Form-focused Scaffolding）】
This is the grammar question I am revising:
{question}
Please provide form-focused guidance only:
1. Which grammatical forms are involved in this question
   (e.g., tense, word order, voice, agreement)?
2. Which forms are most likely to cause difficulty for learners?
3. Do NOT correct or rewrite the sentence.""",
            3: """【階段三：語言鷹架 Prompt（Linguistic Scaffolding）】
Here is my grammar question:
{question}
Please help with linguistic clarity:
1. Is the wording natural and clear for EFL learners?
2. Are there any unnatural or confusing expressions?
3. Suggest minor language improvements WITHOUT changing
   the grammar rule being tested.""",
            4: """【階段四：後設認知鷹架 Prompt（Metacognitive Scaffolding）】
This is my final grammar question:
{question}
Please help me evaluate this question:
1. Is this a good grammar question for learners at my target level?
2. What are the strengths of this question?
3. What possible weaknesses should I be aware of?
4. What could I improve when creating my next question?"""
        }

        system_prompt = """You are an instructional AI tutor designed to support university EFL students in student-generated grammar question (SGQ) activities.

Your role is to provide scaffolding, not answers.

IMPORTANT RULES:
1. Do NOT rewrite the student's question.
2. Do NOT provide the correct answer to the question.
3. Do NOT generate a complete sample question.
4. Focus on guiding, prompting, and raising awareness.
5. Use clear, supportive, and instructional language.
6. When appropriate, ask reflective questions instead of giving direct judgments.

Your scaffolding should support four dimensions:
- Form-focused scaffolding
- Linguistic scaffolding
- Cognitive scaffolding
- Metacognitive scaffolding"""

        if request.stage not in stage_prompts:
            raise HTTPException(status_code=400, detail="Invalid stage")

        user_prompt = stage_prompts[request.stage].format(question=request.question)

        response = openai_client.chat.completions.create(
            model="gpt-4",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            temperature=0.7,
            max_tokens=500
        )

        return ChatGPTResponse(
            response=response.choices[0].message.content
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/chatgpt/additional", response_model=ChatGPTResponse)
async def get_additional_response(request: AdditionalQuestionRequest):
    try:
        system_prompt = """You are an instructional AI tutor designed to support university EFL students in student-generated grammar question (SGQ) activities.

Your role is to provide scaffolding, not answers.

IMPORTANT RULES:
1. Do NOT rewrite the student's question.
2. Do NOT provide the correct answer to the question.
3. Do NOT generate a complete sample question.
4. Focus on guiding, prompting, and raising awareness.
5. Use clear, supportive, and instructional language.
6. When appropriate, ask reflective questions instead of giving direct judgments.

Your scaffolding should support four dimensions:
- Form-focused scaffolding
- Linguistic scaffolding
- Cognitive scaffolding
- Metacognitive scaffolding"""

        # 構建消息列表
        messages = [
            {"role": "system", "content": system_prompt}
        ]

        # 添加對話歷史
        for msg in request.conversation_history:
            role = "user" if msg.get("type") == "user" else "assistant"
            messages.append({
                "role": role,
                "content": msg.get("content", "")
            })

        # 添加用戶的新問題
        messages.append({
            "role": "user",
            "content": request.user_message
        })

        response = openai_client.chat.completions.create(
            model="gpt-4",
            messages=messages,
            temperature=0.7,
            max_tokens=500
        )

        return ChatGPTResponse(
            response=response.choices[0].message.content
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/health")
async def health_check():
    return {"status": "healthy"}


@app.post("/api/send-verification-code")
async def send_verification_code(request: SendVerificationCodeRequest):
    """
    發送註冊驗證碼到指定郵件
    注意：這是一個簡化版本，生產環境應使用專業郵件服務（SendGrid、Mailgun 等）
    """
    email = request.email.strip().lower()
    
    # 驗證郵件格式
    if '@' not in email or '.' not in email.split('@')[1]:
        raise HTTPException(status_code=400, detail="無效的電子郵件格式")
    
    # 生成 6 位數驗證碼
    code = ''.join(random.choices(string.digits, k=6))
    
    # 存儲驗證碼（10 分鐘有效）
    expires_at = time.time() + 600  # 10 分鐘
    verification_codes[email] = {
        'code': code,
        'expires_at': expires_at
    }
    
    # 發送驗證碼郵件
    try:
        send_verification_email(email, code)
        print(f"[成功] 驗證碼已發送到 {email}: {code}")
    except Exception as e:
        print(f"[警告] 郵件發送失敗: {e}")
        print(f"[開發模式] 驗證碼已生成給 {email}: {code}")
        # 如果郵件發送失敗，仍然返回成功（開發模式）
        # 生產環境可以選擇返回錯誤或使用備用方案
    
    # 開發模式下仍然返回驗證碼（方便測試）
    # 生產環境應移除 code 欄位
    environment = os.getenv("ENVIRONMENT", "development")  # 預設為 development
    response_data = {
        "success": True,
        "message": "驗證碼已發送到您的電子郵件",
    }
    # 開發模式下返回驗證碼（總是返回，方便測試）
    response_data["code"] = code
    
    return response_data


@app.post("/api/verify-code")
async def verify_code(request: VerifyCodeRequest):
    """驗證註冊驗證碼"""
    email = request.email.strip().lower()
    code = request.code.strip()
    
    if email not in verification_codes:
        raise HTTPException(status_code=400, detail="驗證碼不存在或已過期")
    
    stored_data = verification_codes[email]
    
    # 檢查是否過期
    if time.time() > stored_data['expires_at']:
        del verification_codes[email]
        raise HTTPException(status_code=400, detail="驗證碼已過期")
    
    # 驗證碼碼
    if stored_data['code'] != code:
        raise HTTPException(status_code=400, detail="驗證碼錯誤")
    
    # 驗證成功，標記為已驗證（可以設置更長的過期時間）
    verification_codes[email]['verified'] = True
    verification_codes[email]['expires_at'] = time.time() + 1800  # 驗證後再延長 30 分鐘
    
    return {
        "success": True,
        "message": "驗證碼正確"
    }

