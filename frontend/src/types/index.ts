export interface User {
  id: string;
  email: string;
  created_at: string;
}

export interface Conversation {
  id: string;
  user_id: string;
  title: string;
  created_at: string;
  updated_at: string;
  lastMessage?: string;
}

export interface Message {
  id: string;
  conversation_id: string;
  role: 'user' | 'assistant';
  content: string;
  created_at: string;
  files?: FileAttachment[];
}

export interface FileAttachment {
  id: string;
  message_id: string;
  filename: string;
  storage_path: string;
  file_size: number;
  file_type: string;
  created_at: string;
}
