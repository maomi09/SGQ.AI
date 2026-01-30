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

class ResetPasswordRequest(BaseModel):
    email: str
    code: str
    new_password: str

class FeedbackRequest(BaseModel):
    subject: str
    content: str
    app_version: Optional[str] = None

class AdminResetPasswordRequest(BaseModel):
    student_email: str
    new_password: str


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

        print(f"[ChatGPT Scaffolding] Stage: {request.stage}, Question: {request.question[:50]}...")
        
        try:
            response = openai_client.chat.completions.create(
                model="gpt-4",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.7,
                max_tokens=500
            )
            
            if not response.choices or len(response.choices) == 0:
                print("[ChatGPT Scaffolding] Error: No choices in response")
                raise HTTPException(status_code=500, detail="OpenAI API returned no choices")
            
            content = response.choices[0].message.content
            if content is None:
                print("[ChatGPT Scaffolding] Error: Response content is None")
                raise HTTPException(status_code=500, detail="OpenAI API returned empty content")
            
            print(f"[ChatGPT Scaffolding] Success: Response length: {len(content)}")
            return ChatGPTResponse(response=content)
            
        except Exception as openai_error:
            print(f"[ChatGPT Scaffolding] OpenAI API Error: {openai_error}")
            print(f"[ChatGPT Scaffolding] Error type: {type(openai_error).__name__}")
            raise HTTPException(
                status_code=500, 
                detail=f"OpenAI API error: {str(openai_error)}"
            )
    except HTTPException:
        raise
    except Exception as e:
        print(f"[ChatGPT Scaffolding] Unexpected error: {e}")
        print(f"[ChatGPT Scaffolding] Error type: {type(e).__name__}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@app.post("/api/chatgpt/additional", response_model=ChatGPTResponse)
async def get_additional_response(request: AdditionalQuestionRequest):
    try:
        print(f"[ChatGPT Additional] Stage: {request.stage}, User message: {request.user_message[:50]}...")
        
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

        try:
            response = openai_client.chat.completions.create(
                model="gpt-4",
                messages=messages,
                temperature=0.7,
                max_tokens=500
            )
            
            if not response.choices or len(response.choices) == 0:
                print("[ChatGPT Additional] Error: No choices in response")
                raise HTTPException(status_code=500, detail="OpenAI API returned no choices")
            
            content = response.choices[0].message.content
            if content is None:
                print("[ChatGPT Additional] Error: Response content is None")
                raise HTTPException(status_code=500, detail="OpenAI API returned empty content")
            
            print(f"[ChatGPT Additional] Success: Response length: {len(content)}")
            return ChatGPTResponse(response=content)
            
        except Exception as openai_error:
            print(f"[ChatGPT Additional] OpenAI API Error: {openai_error}")
            print(f"[ChatGPT Additional] Error type: {type(openai_error).__name__}")
            raise HTTPException(
                status_code=500, 
                detail=f"OpenAI API error: {str(openai_error)}"
            )
    except HTTPException:
        raise
    except Exception as e:
        print(f"[ChatGPT Additional] Unexpected error: {e}")
        print(f"[ChatGPT Additional] Error type: {type(e).__name__}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


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
    
    # 驗證碼只會發送到電子郵件，不會在 API 響應中返回
    # 這是為了安全考慮，防止驗證碼洩露
    return {
        "success": True,
        "message": "驗證碼已發送到您的電子郵件",
    }


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


@app.post("/api/reset-password")
async def reset_password(request: ResetPasswordRequest):
    """重設密碼（需要先驗證驗證碼）"""
    email = request.email.strip().lower()
    code = request.code.strip()
    new_password = request.new_password
    
    # 驗證密碼長度
    if len(new_password) < 6:
        raise HTTPException(status_code=400, detail="密碼長度至少需要6個字符")
    
    # 驗證驗證碼
    if email not in verification_codes:
        raise HTTPException(status_code=400, detail="驗證碼不存在或已過期")
    
    stored_data = verification_codes[email]
    
    # 檢查是否已驗證
    if not stored_data.get('verified', False):
        raise HTTPException(status_code=400, detail="請先驗證驗證碼")
    
    # 檢查是否過期
    if time.time() > stored_data['expires_at']:
        del verification_codes[email]
        raise HTTPException(status_code=400, detail="驗證碼已過期，請重新發送")
    
    # 再次驗證驗證碼（確保安全）
    if stored_data['code'] != code:
        raise HTTPException(status_code=400, detail="驗證碼錯誤")
    
    try:
        # 使用 Supabase Admin API 更新密碼
        # 注意：這需要使用 service_role key，而不是 anon key
        from supabase import create_client
        
        supabase_service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        if not supabase_service_key:
            # 如果沒有 service_role key，嘗試使用 Supabase Admin API
            # 或者使用其他方式更新密碼
            raise HTTPException(status_code=500, detail="服務器配置錯誤：缺少 SUPABASE_SERVICE_ROLE_KEY")
        
        # 創建使用 service_role 的 Supabase 客戶端
        admin_supabase = create_client(supabase_url, supabase_service_key)
        
        # 查找用戶
        users_response = admin_supabase.auth.admin.list_users()
        user = None
        for u in users_response.users:
            if u.email == email:
                user = u
                break
        
        if not user:
            raise HTTPException(status_code=404, detail="找不到該電子郵件地址的用戶")
        
        # 使用 Admin API 更新用戶密碼
        admin_supabase.auth.admin.update_user_by_id(
            user.id,
            {"password": new_password}
        )
        
        # 清除驗證碼（已使用）
        del verification_codes[email]
        
        return {
            "success": True,
            "message": "密碼重設成功"
        }
    except Exception as e:
        print(f"重設密碼錯誤: {e}")
        raise HTTPException(status_code=500, detail=f"重設密碼失敗: {str(e)}")


def send_feedback_email(subject: str, content: str, app_version: str = None):
    """發送反饋郵件到 sgqaiapp@gmail.com"""
    feedback_email = "sgqaiapp@gmail.com"
    
    # 從環境變數讀取郵件設定
    smtp_enabled = os.getenv("SMTP_ENABLED", "false").lower() == "true"
    sendgrid_enabled = os.getenv("SENDGRID_ENABLED", "false").lower() == "true"
    
    # 優先使用 SendGrid（如果啟用）
    if sendgrid_enabled:
        try:
            send_feedback_with_sendgrid(feedback_email, subject, content, app_version)
            return
        except Exception as e:
            print(f"SendGrid 發送失敗，嘗試 SMTP: {e}")
    
    # 使用 SMTP（如果啟用）
    if smtp_enabled:
        send_feedback_with_smtp(feedback_email, subject, content, app_version)
    else:
        # 如果都沒有啟用，拋出異常
        raise Exception("郵件服務未配置。請設置 SMTP_ENABLED=true 或 SENDGRID_ENABLED=true")


def send_feedback_with_smtp(to_email: str, subject: str, content: str, app_version: str = None):
    """使用 SMTP 發送反饋郵件"""
    smtp_server = os.getenv("SMTP_SERVER", "smtp.gmail.com")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_username = os.getenv("SMTP_USERNAME")
    smtp_password = os.getenv("SMTP_PASSWORD")
    smtp_from_email = os.getenv("SMTP_FROM_EMAIL", smtp_username)
    
    if not smtp_username or not smtp_password:
        raise Exception("SMTP 設定不完整。請設置 SMTP_USERNAME 和 SMTP_PASSWORD")
    
    # 創建郵件
    msg = MIMEMultipart('alternative')
    msg['Subject'] = f'[應用程式回報] {subject}'
    msg['From'] = smtp_from_email
    msg['To'] = to_email
    
    # 郵件內容（HTML）
    version_info = f"<p><strong>應用程式版本：</strong>{app_version or '未知'}</p>" if app_version else ""
    
    html_content = f"""
    <html>
      <body>
        <h2>應用程式回報</h2>
        <p><strong>主旨：</strong>{subject}</p>
        {version_info}
        <hr>
        <h3>詳細內容：</h3>
        <p style="white-space: pre-wrap;">{content}</p>
      </body>
    </html>
    """
    
    # 純文字版本
    text_content = f"""
應用程式回報

主旨：{subject}
{'' if not app_version else f'應用程式版本：{app_version}'}

詳細內容：
{content}
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
        print(f"反饋郵件已通過 SMTP 發送到 {to_email}")
    except Exception as e:
        raise Exception(f"SMTP 發送失敗: {str(e)}")


def send_feedback_with_sendgrid(to_email: str, subject: str, content: str, app_version: str = None):
    """使用 SendGrid 發送反饋郵件"""
    try:
        from sendgrid import SendGridAPIClient
        from sendgrid.helpers.mail import Mail
    except ImportError:
        raise Exception("SendGrid 套件未安裝。請執行: pip install sendgrid")
    
    sendgrid_api_key = os.getenv("SENDGRID_API_KEY")
    sendgrid_from_email = os.getenv("SENDGRID_FROM_EMAIL", "noreply@yourapp.com")
    
    if not sendgrid_api_key:
        raise Exception("SENDGRID_API_KEY 未設置")
    
    version_info = f"<p><strong>應用程式版本：</strong>{app_version or '未知'}</p>" if app_version else ""
    
    message = Mail(
        from_email=sendgrid_from_email,
        to_emails=to_email,
        subject=f'[應用程式回報] {subject}',
        html_content=f"""
        <h2>應用程式回報</h2>
        <p><strong>主旨：</strong>{subject}</p>
        {version_info}
        <hr>
        <h3>詳細內容：</h3>
        <p style="white-space: pre-wrap;">{content}</p>
        """
    )
    
    try:
        sg = SendGridAPIClient(sendgrid_api_key)
        response = sg.send(message)
        print(f"反饋郵件已通過 SendGrid 發送到 {to_email}, 狀態碼: {response.status_code}")
    except Exception as e:
        raise Exception(f"SendGrid 發送失敗: {str(e)}")


@app.post("/api/send-feedback")
async def send_feedback(request: FeedbackRequest):
    """發送用戶反饋到 sgqaiapp@gmail.com"""
    try:
        send_feedback_email(
            subject=request.subject,
            content=request.content,
            app_version=request.app_version
        )
        
        return {
            "success": True,
            "message": "反饋已成功發送"
        }
    except Exception as e:
        print(f"發送反饋錯誤: {e}")
        raise HTTPException(status_code=500, detail=f"發送反饋失敗: {str(e)}")


@app.post("/api/admin/reset-student-password")
async def admin_reset_student_password(request: AdminResetPasswordRequest):
    """老師重置學生密碼（需要 SUPABASE_SERVICE_ROLE_KEY）"""
    student_email = request.student_email.strip().lower()
    new_password = request.new_password
    
    # 驗證密碼長度
    if len(new_password) < 6:
        raise HTTPException(status_code=400, detail="密碼長度至少需要6個字符")
    
    try:
        # 使用 Supabase Admin API 更新密碼
        supabase_service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        if not supabase_service_key:
            raise HTTPException(status_code=500, detail="服務器配置錯誤：缺少 SUPABASE_SERVICE_ROLE_KEY")
        
        # 創建使用 service_role 的 Supabase 客戶端
        admin_supabase = create_client(supabase_url, supabase_service_key)
        
        # 查找學生用戶
        users_response = admin_supabase.auth.admin.list_users()
        user = None
        for u in users_response.users:
            if u.email == student_email:
                user = u
                break
        
        if not user:
            raise HTTPException(status_code=404, detail="找不到該電子郵件地址的學生")
        
        # 驗證該用戶是學生（可選，但建議檢查）
        try:
            user_data = admin_supabase.table('users').select('role').eq('id', user.id).single().execute()
            if user_data.data['role'] != 'student':
                raise HTTPException(status_code=403, detail="該帳號不是學生帳號")
        except Exception as e:
            print(f"Warning: Could not verify user role: {e}")
            # 如果無法驗證，仍然繼續（可能是 RLS 問題）
        
        # 使用 Admin API 更新學生密碼
        admin_supabase.auth.admin.update_user_by_id(
            user.id,
            {"password": new_password}
        )
        
        return {
            "success": True,
            "message": "學生密碼已重置"
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"重置學生密碼錯誤: {e}")
        raise HTTPException(status_code=500, detail=f"重置密碼失敗: {str(e)}")

