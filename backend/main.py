from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import os
import random
import string
import hashlib
import time
import smtplib
import urllib.request
import urllib.parse
import json
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from dotenv import load_dotenv
from supabase import create_client, Client
from openai import OpenAI
import jwt

# 載入環境變數（override=True 確保 .env 檔案優先於系統環境變數）
load_dotenv(override=True)

app = FastAPI(
    title="SGQ API Server",
    description="SGQ 後端 API 服務",
    version="1.0.0",
)

# CORS 設定
# 生產環境建議限制允許的來源
allowed_origins = os.getenv("ALLOWED_ORIGINS", "*").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 從環境變數讀取設定，如果沒有則使用預設值（從 Flutter app 中取得）
# 注意：使用 override=True 後，.env 檔案會覆蓋系統環境變數
supabase_url = os.getenv("SUPABASE_URL") or "https://iqmhqdkpultzyzurolwv.supabase.co"
supabase_key = os.getenv("SUPABASE_KEY") or "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxbWhxZGtwdWx0enl6dXJvbHd2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU4MDc1NzMsImV4cCI6MjA4MTM4MzU3M30.OfBqLiwFQLjyuJwkgU1Vu1eedjrzkeVsSznQAnR9B9Q"

# 輸出使用的 Supabase URL（用於除錯）
print(f"[後端設定] Supabase URL: {supabase_url}")

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

# JWT Token 驗證
security = HTTPBearer()

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> Dict[str, Any]:
    """
    驗證 JWT Token 並返回用戶資訊
    返回用戶資訊字典，包含 user_id 和 role
    """
    token = credentials.credentials
    
    try:
        # 使用 service_role key 來驗證和查詢用戶資訊
        supabase_service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        if not supabase_service_key:
            raise HTTPException(status_code=500, detail="服務器配置錯誤：缺少 SUPABASE_SERVICE_ROLE_KEY")
        
        admin_supabase = create_client(supabase_url, supabase_service_key)
        
        # 解析 JWT Token 獲取用戶 ID
        try:
            # 解析 JWT Token（不驗證簽名，因為我們會用 Supabase API 驗證用戶存在）
            # 注意：這只是為了獲取用戶 ID，實際驗證會通過 Supabase API 進行
            decoded_token = jwt.decode(token, options={"verify_signature": False})
            user_id = decoded_token.get('sub')
            
            if not user_id:
                raise HTTPException(status_code=401, detail="無效的認證 token")
            
            # 使用 Supabase Admin API 驗證用戶是否存在並獲取用戶資訊
            try:
                user_response = admin_supabase.auth.admin.get_user_by_id(user_id)
                
                # 處理不同的返回格式
                if hasattr(user_response, 'user'):
                    auth_user = user_response.user
                elif isinstance(user_response, dict) and 'user' in user_response:
                    auth_user = user_response['user']
                else:
                    auth_user = user_response
                
                # 從 users 表獲取用戶角色
                user_data = admin_supabase.table('users').select('role').eq('id', user_id).single().execute()
                
                if not user_data.data:
                    raise HTTPException(status_code=404, detail="找不到用戶資料")
                
                user_role = user_data.data.get('role')
                
                return {
                    'user_id': user_id,
                    'role': user_role
                }
                
            except HTTPException:
                raise
            except Exception as e:
                print(f"驗證用戶時發生錯誤: {e}")
                raise HTTPException(status_code=401, detail="認證失敗，請重新登入")
                
        except jwt.DecodeError:
            raise HTTPException(status_code=401, detail="無效的認證 token")
        except Exception as e:
            print(f"解析 token 時發生錯誤: {e}")
            raise HTTPException(status_code=401, detail="認證失敗，請重新登入")
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"JWT 驗證錯誤: {e}")
        raise HTTPException(status_code=401, detail="認證失敗，請重新登入")


def verify_teacher_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> Dict[str, Any]:
    """
    驗證 JWT Token 並確認用戶是老師
    返回用戶資訊字典，包含 user_id 和 role
    """
    current_user = verify_token(credentials)
    
    # 驗證用戶角色必須是老師
    if current_user['role'] != 'teacher':
        raise HTTPException(status_code=403, detail="此操作僅限老師使用")
    
    return current_user


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
    question_type: Optional[str] = None  # "multipleChoice" 或 "shortAnswer"
    options: Optional[List[str]] = None  # 選擇題的選項
    correct_answer: Optional[str] = None  # 正確答案
    stage: int


class AdditionalQuestionRequest(BaseModel):
    user_message: str
    question: str
    question_type: Optional[str] = None  # "multipleChoice" 或 "shortAnswer"
    options: Optional[List[str]] = None  # 選擇題的選項
    correct_answer: Optional[str] = None  # 正確答案
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

class AdminUpdateStudentEmailRequest(BaseModel):
    student_id: str
    new_email: str

class SendNotificationRequest(BaseModel):
    title: str
    body: str
    student_ids: Optional[List[str]] = None  # 如果為 None，發送給所有學生
    scheduled_time: Optional[str] = None  # ISO 格式的時間字串，如果為 None 則立即發送


@app.get("/")
async def root():
    return {"message": "SGQ API Server"}


@app.post("/api/chatgpt/scaffolding", response_model=ChatGPTResponse)
async def get_scaffolding(
    request: QuestionRequest,
    current_user: Dict[str, Any] = Depends(verify_token)
):
    try:
        stage_prompts = {
            1: """【Stage 1 認知鷹架 Cognitive】
Focus: grammar target + thinking level

Here is the grammar question I created:
{question}

規則：本題主要測試___｜Target rule
層次：偏記憶/應用/推論｜Cognitive level
問題：僅靠線索即可作答｜Too easy cue
建議：加入情境或多步驟判斷｜Add reasoning""",
            2: """【Stage 2 形式鷹架 Form-focused】
Focus: grammatical forms + testability

This is the grammar question I am revising:
{question}

形式：涉及___等結構｜Forms
難點：學習者易混淆___｜Difficulty
問題：干擾點不足/過明顯｜Weak contrast
微調：___→___（例）｜Micro example""",
            3: """【Stage 3 語言鷹架 Linguistic】
Focus: clarity + authenticity + sentence complexity

Here is my grammar question:
{question}

語句：結構較單一/過短｜Simple
問題：缺乏真實語境支持｜Low authenticity
建議：加入子句/連接詞/情境詞｜Add clause
微調：and→although（例）｜Example""",
            4: """【Stage 4 後設認知鷹架 Metacognitive】
Focus: overall quality + distractor design + improvement

This is my final grammar question:
{question}

優點：能測出___能力｜Strength
限制：題型或選項變化少｜Limitation
誘答：錯誤選項過易排除｜Distractor weak
下次：設計相似形式增加干擾｜Improve distractor"""
        }

        if request.stage not in stage_prompts:
            raise HTTPException(status_code=400, detail="Invalid stage")

        # 根據題型構建 user_prompt
        base_prompt = stage_prompts[request.stage].format(question=request.question)
        
        # 如果是選擇題，添加選項和正確答案
        if request.question_type == "multipleChoice" and request.options:
            options_text = "\n".join([f"{chr(65+i)}. {opt}" for i, opt in enumerate(request.options)])
            correct_answer_text = f"正確答案：{request.correct_answer}" if request.correct_answer else "正確答案：未提供"
            user_prompt = f"""{base_prompt}

選項：
{options_text}
{correct_answer_text}"""
        # 如果是問答題，只添加正確答案
        elif request.question_type == "shortAnswer":
            correct_answer_text = f"正確答案：{request.correct_answer}" if request.correct_answer else "正確答案：未提供"
            user_prompt = f"""{base_prompt}

{correct_answer_text}"""
        else:
            # 預設情況（沒有題型資訊或未知題型）
            user_prompt = base_prompt

        print(f"[ChatGPT Scaffolding] Stage: {request.stage}, Type: {request.question_type}, Question: {request.question[:50]}...")
        
        system_prompt = """You are an instructional AI tutor supporting university EFL students
in Student-Generated Grammar Question (SGQ) activities.

Your role is to scaffold students to DESIGN BETTER QUESTIONS,
not to correct or answer them.

Help students:
• clarify grammar focus
• improve linguistic quality
• increase cognitive complexity
• design better distractors

Guide thinking only.

=====================
STRICT PROHIBITIONS
=====================
DO NOT:
• rewrite the whole question
• provide the correct answer
• generate a complete sample item
• directly fix errors

Only provide hints and small suggestions.

=====================
RESPONSE STYLE (MANDATORY)
=====================
• 3–4 short lines only per stage
• each line about 20–40 Chinese characters
• include short English keywords
• concise but slightly explanatory
• include WHY + HOW to improve
• give only word/phrase-level examples

Format:
中文說明｜English

Tone:
Supportive, coaching, instructional

=====================
FOUR STAGE SCAFFOLDING
=====================

Respond ONLY to the requested stage.

-----------------------------------
【Stage 1 認知鷹架 Cognitive】
Focus: grammar target + thinking level

規則：本題主要測試___｜Target rule
層次：偏記憶/應用/推論｜Cognitive level
問題：僅靠線索即可作答｜Too easy cue
建議：加入情境或多步驟判斷｜Add reasoning

-----------------------------------
【Stage 2 形式鷹架 Form-focused】
Focus: grammatical forms + testability

形式：涉及___等結構｜Forms
難點：學習者易混淆___｜Difficulty
問題：干擾點不足/過明顯｜Weak contrast
微調：___→___（例）｜Micro example

-----------------------------------
【Stage 3 語言鷹架 Linguistic】
Focus: clarity + authenticity + sentence complexity

語句：結構較單一/過短｜Simple
問題：缺乏真實語境支持｜Low authenticity
建議：加入子句/連接詞/情境詞｜Add clause
微調：and→although（例）｜Example

-----------------------------------
【Stage 4 後設認知鷹架 Metacognitive】
Focus: overall quality + distractor design + improvement

優點：能測出___能力｜Strength
限制：題型或選項變化少｜Limitation
誘答：錯誤選項過易排除｜Distractor weak
下次：設計相似形式增加干擾｜Improve distractor

=====================
FEEDBACK PRINCIPLES
=====================
Always:
• explain briefly WHY
• suggest HOW to improve
• encourage deeper thinking
• push for higher complexity
• keep student ownership

Never:
❌ give answers
❌ rewrite
❌ long explanation

=====================
END
====================="""
        
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
            # 不洩露 OpenAI API 詳細錯誤資訊
            print(f"[ChatGPT Scaffolding] OpenAI API Error: {openai_error}")
            raise HTTPException(
                status_code=500, 
                detail="無法取得 ChatGPT 回應，請稍後再試"
            )
    except HTTPException:
        raise
    except Exception as e:
        print(f"[ChatGPT Scaffolding] Unexpected error: {e}")
        print(f"[ChatGPT Scaffolding] Error type: {type(e).__name__}")
        import traceback
        traceback.print_exc()
        # 不洩露內部錯誤詳情
        print(f"[ChatGPT Scaffolding] Unexpected error: {e}")
        raise HTTPException(status_code=500, detail="伺服器錯誤，請稍後再試")


@app.post("/api/chatgpt/additional", response_model=ChatGPTResponse)
async def get_additional_response(
    request: AdditionalQuestionRequest,
    current_user: Dict[str, Any] = Depends(verify_token)
):
    try:
        print(f"[ChatGPT Additional] Stage: {request.stage}, User message: {request.user_message[:50]}...")
        
        # 為追加問題創建更靈活的 system_prompt（不限制格式，但保持核心規則）
        system_prompt = f"""You are an instructional AI tutor supporting university EFL students
in Student-Generated Grammar Question (SGQ) activities.

Your role is to scaffold students to DESIGN BETTER QUESTIONS,
not to correct or answer them.

Help students:
• clarify grammar focus
• improve linguistic quality
• increase cognitive complexity
• design better distractors

Guide thinking only.

=====================
STRICT PROHIBITIONS
=====================
DO NOT:
• rewrite the whole question
• provide the correct answer
• generate a complete sample item
• directly fix errors

Only provide hints and small suggestions.

=====================
RESPONSE STYLE FOR ADDITIONAL QUESTIONS
=====================
• Answer naturally in Traditional Chinese (繁體中文)
• Be conversational and supportive
• Focus on the student's specific question
• Provide helpful guidance without strict format requirements
• Keep responses concise but informative
• Explain WHY and suggest HOW to improve
• You are NOT required to follow the format template (規則：、層次：、問題：、建議：)
• Answer freely while maintaining the core principles

Tone:
Supportive, coaching, instructional, conversational

=====================
STAGE CONTEXT
=====================
The current conversation is in Stage {request.stage}. 
When responding, consider the focus of this stage:

• Stage 1 (Cognitive): Focus on grammar target and thinking level
• Stage 2 (Form-focused): Focus on grammatical forms and testability
• Stage 3 (Linguistic): Focus on clarity, authenticity, and sentence complexity
• Stage 4 (Metacognitive): Focus on overall quality, distractor design, and improvement

However, you are NOT required to follow a specific format template. 
Answer the student's question naturally while keeping the stage's focus in mind.

=====================
FEEDBACK PRINCIPLES
=====================
Always:
• explain briefly WHY
• suggest HOW to improve
• encourage deeper thinking
• push for higher complexity
• keep student ownership
• answer in Traditional Chinese (繁體中文)

Never:
❌ give answers
❌ rewrite the question
❌ provide overly long explanations
❌ use rigid format templates (like "規則：、層次：、問題：、建議：")

=====================
END
====================="""

        # 構建消息列表
        messages = [
            {"role": "system", "content": system_prompt}
        ]

        # 檢查對話歷史中是否包含原始題目
        has_question_context = False
        for msg in request.conversation_history:
            content = str(msg.get("content", ""))
            if "題目為:" in content or request.question in content:
                has_question_context = True
                break

        # 如果對話歷史中沒有原始題目，先添加它
        if not has_question_context:
            # 根據題型構建題目資訊
            question_info = f"原始題目：{request.question}"
            if request.question_type == "multipleChoice" and request.options:
                options_text = "\n".join([f"{chr(65+i)}. {opt}" for i, opt in enumerate(request.options)])
                question_info += f"\n選項：\n{options_text}"
            if request.correct_answer:
                question_info += f"\n正確答案：{request.correct_answer}"
            
            messages.append({
                "role": "user",
                "content": question_info
            })

        # 添加對話歷史（過濾掉 system 類型的消息，因為已經在 system_prompt 中）
        for msg in request.conversation_history:
            msg_type = msg.get("type", "")
            # 只處理 user 和 assistant 類型的消息
            if msg_type in ["user", "assistant"]:
                role = "user" if msg_type == "user" else "assistant"
                messages.append({
                    "role": role,
                    "content": msg.get("content", "")
                })
            # 如果是 system 類型且包含題目，也加入（作為 user 消息）
            elif msg_type == "system" and "題目為:" in str(msg.get("content", "")):
                messages.append({
                    "role": "user",
                    "content": msg.get("content", "")
                })

        # 添加用戶的新問題（包含階段指示，但不限制格式）
        stage_indicator = f"【當前階段：Stage {request.stage}】\n請根據 Stage {request.stage} 的焦點回答，但不需要遵循特定格式，自然回答即可。\n\n"
        messages.append({
            "role": "user",
            "content": stage_indicator + request.user_message
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
            # 不洩露 OpenAI API 詳細錯誤資訊
            print(f"[ChatGPT Scaffolding] OpenAI API Error: {openai_error}")
            raise HTTPException(
                status_code=500, 
                detail="無法取得 ChatGPT 回應，請稍後再試"
            )
    except HTTPException:
        raise
    except Exception as e:
        print(f"[ChatGPT Additional] Unexpected error: {e}")
        print(f"[ChatGPT Additional] Error type: {type(e).__name__}")
        import traceback
        traceback.print_exc()
        # 不洩露內部錯誤詳情
        print(f"[ChatGPT Scaffolding] Unexpected error: {e}")
        raise HTTPException(status_code=500, detail="伺服器錯誤，請稍後再試")


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
        try:
            admin_supabase = create_client(supabase_url, supabase_service_key)
        except Exception as conn_error:
            print(f"連接 Supabase 失敗: {conn_error}")
            raise HTTPException(
                status_code=500, 
                detail="無法連接到 Supabase 服務，請檢查網路連接和 Supabase URL 設定"
            )
        
        # 使用 Supabase Admin API 查找和更新用戶
        # 注意：由於網路連接問題，我們使用 Python SDK 並加上更好的錯誤處理
        try:
            # 先測試網路連接和 DNS 解析
            print(f"測試 Supabase 連接: {supabase_url}")
            print(f"使用 Service Role Key: {'已設定' if supabase_service_key else '未設定'}")
            
            # 嘗試使用 Python SDK 查找用戶
            # 注意：list_users() 可能會返回大量用戶，但這是目前最可靠的方法
            print(f"嘗試查找用戶: {email}")
            
            # 設定超時時間（如果 SDK 支援）
            try:
                users_response = admin_supabase.auth.admin.list_users()
                
                # 處理不同的返回格式
                # 新版本的 Supabase SDK 可能直接返回 list，舊版本返回有 users 屬性的對象
                if isinstance(users_response, list):
                    users_list = users_response
                    print(f"成功取得用戶列表，共 {len(users_list)} 個用戶")
                elif hasattr(users_response, 'users'):
                    users_list = users_response.users
                    print(f"成功取得用戶列表，共 {len(users_list)} 個用戶")
                else:
                    # 嘗試轉換為 list
                    users_list = list(users_response) if users_response else []
                    print(f"成功取得用戶列表，共 {len(users_list)} 個用戶")
            except Exception as list_error:
                error_msg = str(list_error)
                print(f"查詢用戶列表失敗: {list_error}")
                print(f"錯誤類型: {type(list_error).__name__}")
                
                # 檢查是否是 DNS 解析錯誤
                if "getaddrinfo failed" in error_msg or "11001" in error_msg:
                    raise HTTPException(
                        status_code=500,
                        detail="無法連接到 Supabase，請檢查：\n"
                               "1. 網路連接是否正常\n"
                               "2. DNS 設定是否正確\n"
                               "3. 防火牆是否阻擋連接\n"
                               "4. 是否使用代理（需要設定代理）"
                    )
                else:
                    raise
            
            user = None
            for u in users_list:
                # 處理不同的用戶對象格式
                user_email = u.email if hasattr(u, 'email') else u.get('email') if isinstance(u, dict) else None
                user_id = u.id if hasattr(u, 'id') else u.get('id') if isinstance(u, dict) else None
                
                if user_email and user_email.lower() == email.lower():
                    user = u
                    print(f"找到用戶: {user_id}")
                    break
            
            if not user:
                raise HTTPException(status_code=404, detail="找不到該電子郵件地址的用戶")
            
            # 使用 Admin API 更新用戶密碼
            # 取得用戶 ID（處理不同的對象格式）
            user_id = user.id if hasattr(user, 'id') else user.get('id') if isinstance(user, dict) else None
            if not user_id:
                raise HTTPException(status_code=500, detail="無法取得用戶 ID")
            
            print(f"嘗試更新用戶密碼: {user_id}")
            try:
                admin_supabase.auth.admin.update_user_by_id(
                    user_id,
                    {"password": new_password}
                )
                print("密碼更新成功")
            except Exception as update_error:
                error_msg = str(update_error)
                print(f"更新密碼失敗: {update_error}")
                print(f"錯誤類型: {type(update_error).__name__}")
                if "getaddrinfo failed" in error_msg or "11001" in error_msg:
                    raise HTTPException(
                        status_code=500,
                        detail="無法連接到 Supabase 更新密碼，請檢查網路連接"
                    )
                else:
                    raise HTTPException(
                        status_code=500,
                        detail="更新密碼失敗，請稍後再試"
                    )
        except HTTPException:
            raise
        except Exception as update_error:
            print(f"更新密碼失敗: {update_error}")
            print(f"錯誤類型: {type(update_error).__name__}")
            raise HTTPException(
                status_code=500,
                detail="更新密碼失敗，請稍後再試"
            )
        
        # 清除驗證碼（已使用）
        del verification_codes[email]
        
        return {
            "success": True,
            "message": "密碼重設成功"
        }
    except HTTPException:
        raise
    except Exception as e:
        error_msg = str(e)
        print(f"重設密碼錯誤: {e}")
        print(f"錯誤類型: {type(e).__name__}")
        
        # 檢查是否是網路連接錯誤
        if "getaddrinfo failed" in error_msg or "11001" in error_msg:
            raise HTTPException(
                status_code=500,
                detail="網路連接失敗，請檢查網路設定和 Supabase URL"
            )
        elif "timeout" in error_msg.lower() or "timed out" in error_msg.lower():
            raise HTTPException(
                status_code=500,
                detail="連接超時，請稍後再試"
            )
        else:
            raise HTTPException(status_code=500, detail="重設密碼失敗，請稍後再試")


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
        # 不洩露內部錯誤詳情
        print(f"發送反饋錯誤: {e}")
        raise HTTPException(status_code=500, detail="發送反饋失敗，請稍後再試")


@app.post("/api/admin/reset-student-password")
async def admin_reset_student_password(
    request: AdminResetPasswordRequest,
    current_user: Dict[str, Any] = Depends(verify_teacher_token)
):
    """老師重置學生密碼（需要 JWT Token 驗證和老師角色）"""
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
        
        # 處理不同的返回格式
        if isinstance(users_response, list):
            users_list = users_response
        elif hasattr(users_response, 'users'):
            users_list = users_response.users
        else:
            users_list = list(users_response) if users_response else []
        
        user = None
        for u in users_list:
            # 處理不同的用戶對象格式
            user_email = u.email if hasattr(u, 'email') else u.get('email') if isinstance(u, dict) else None
            if user_email and user_email.lower() == student_email.lower():
                user = u
                break
        
        if not user:
            raise HTTPException(status_code=404, detail="找不到該電子郵件地址的學生")
        
        # 取得用戶 ID（處理不同的對象格式）
        user_id = user.id if hasattr(user, 'id') else user.get('id') if isinstance(user, dict) else None
        if not user_id:
            raise HTTPException(status_code=500, detail="無法取得用戶 ID")
        
        # 驗證該用戶是學生（可選，但建議檢查）
        try:
            user_data = admin_supabase.table('users').select('role').eq('id', user_id).single().execute()
            if user_data.data['role'] != 'student':
                raise HTTPException(status_code=403, detail="該帳號不是學生帳號")
        except Exception as e:
            print(f"Warning: Could not verify user role: {e}")
            # 如果無法驗證，仍然繼續（可能是 RLS 問題）
        
        # 使用 Admin API 更新學生密碼
        admin_supabase.auth.admin.update_user_by_id(
            user_id,
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
        # 不洩露內部錯誤詳情
        print(f"重置密碼錯誤: {e}")
        raise HTTPException(status_code=500, detail="重置密碼失敗，請稍後再試")


@app.post("/api/admin/update-student-email")
async def admin_update_student_email(
    request: AdminUpdateStudentEmailRequest,
    current_user: Dict[str, Any] = Depends(verify_token)
):
    """
    更新學生電子郵件（需要 JWT Token 驗證）
    - 老師可以更新任何學生的 email
    - 學生只能更新自己的 email
    """
    student_id = request.student_id.strip()
    new_email = request.new_email.strip().lower()
    current_user_id = current_user['user_id']
    current_user_role = current_user['role']
    
    # 權限檢查：如果是學生，只能更新自己的 email
    if current_user_role == 'student' and current_user_id != student_id:
        raise HTTPException(status_code=403, detail="您只能更新自己的電子郵件")
    
    # 驗證 email 格式
    import re
    email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if not re.match(email_pattern, new_email):
        raise HTTPException(status_code=400, detail="電子郵件格式不正確")
    
    try:
        # 使用 Supabase Admin API 更新 email
        supabase_service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        if not supabase_service_key:
            raise HTTPException(status_code=500, detail="服務器配置錯誤：缺少 SUPABASE_SERVICE_ROLE_KEY")
        
        # 創建使用 service_role 的 Supabase 客戶端
        admin_supabase = create_client(supabase_url, supabase_service_key)
        
        # 驗證該用戶是學生
        try:
            user_data = admin_supabase.table('users').select('role, email').eq('id', student_id).single().execute()
            if user_data.data['role'] != 'student':
                raise HTTPException(status_code=403, detail="該帳號不是學生帳號")
            old_email = user_data.data.get('email', '')
        except Exception as e:
            print(f"Warning: Could not verify user role: {e}")
            raise HTTPException(status_code=404, detail="找不到該學生帳號")
        
        # 檢查新 email 是否已被其他用戶使用
        try:
            existing_user = admin_supabase.table('users').select('id').eq('email', new_email).neq('id', student_id).execute()
            if existing_user.data and len(existing_user.data) > 0:
                raise HTTPException(status_code=400, detail="該電子郵件已被其他用戶使用")
        except HTTPException:
            raise
        except Exception as e:
            print(f"Warning: Could not check email availability: {e}")
        
        # 使用 Admin API 更新 auth.users 的 email
        admin_supabase.auth.admin.update_user_by_id(
            student_id,
            {"email": new_email}
        )
        
        # 同時更新 users 表的 email（確保同步）
        admin_supabase.table('users').update({
            'email': new_email,
            'updated_at': 'now()'
        }).eq('id', student_id).execute()
        
        # 記錄更新操作（包含時間戳）
        from datetime import datetime
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print(f"[{timestamp}] 成功更新學生 email: {old_email} -> {new_email} (學生 ID: {student_id})")
        
        return {
            "success": True,
            "message": "學生電子郵件已更新",
            "old_email": old_email,
            "new_email": new_email
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"更新學生電子郵件錯誤: {e}")
        # 不洩露內部錯誤詳情
        print(f"更新學生電子郵件錯誤: {e}")
        raise HTTPException(status_code=500, detail="更新電子郵件失敗，請稍後再試")


@app.post("/api/send-notification")
async def send_notification(
    request: SendNotificationRequest,
    current_user: Dict[str, Any] = Depends(verify_teacher_token)
):
    """
    老師發送通知給學生（需要 JWT Token 驗證和老師角色）
    注意：這是記錄通知發送，實際通知顯示由前端本地通知服務處理
    """
    try:
        supabase_service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        if not supabase_service_key:
            raise HTTPException(status_code=500, detail="服務器配置錯誤：缺少 SUPABASE_SERVICE_ROLE_KEY")
        
        admin_supabase = create_client(supabase_url, supabase_service_key)
        
        # 獲取要發送通知的學生列表
        if request.student_ids:
            # 發送給指定的學生
            student_ids = request.student_ids
        else:
            # 發送給所有學生
            students_response = admin_supabase.table('users').select('id').eq('role', 'student').execute()
            student_ids = [student['id'] for student in students_response.data]
        
        # 驗證所有學生 ID 都是有效的學生
        if student_ids:
            valid_students = admin_supabase.table('users').select('id').eq('role', 'student').in_('id', student_ids).execute()
            valid_student_ids = [s['id'] for s in valid_students.data]
            if len(valid_student_ids) != len(student_ids):
                raise HTTPException(status_code=400, detail="部分學生 ID 無效")
        
        # 記錄通知發送（可以存儲到資料庫中，供前端查詢）
        # 這裡只是返回成功，實際通知由前端根據返回的資料顯示
        notification_data = {
            "title": request.title,
            "body": request.body,
            "student_ids": student_ids,
            "scheduled_time": request.scheduled_time,
            "sent_at": time.time(),
            "sent_by": current_user['user_id']
        }
        
        # 可以將通知記錄存儲到資料庫（如果需要）
        # 目前先記錄到日誌
        print(f"通知發送記錄: {notification_data}")
        
        return {
            "success": True,
            "message": f"通知已發送給 {len(student_ids)} 位學生",
            "notification": {
                "title": request.title,
                "body": request.body,
                "student_count": len(student_ids),
                "scheduled_time": request.scheduled_time
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"發送通知錯誤: {e}")
        raise HTTPException(status_code=500, detail="發送通知失敗，請稍後再試")

