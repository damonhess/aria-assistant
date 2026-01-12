import { create } from 'zustand';
import { Session } from '@supabase/supabase-js';
import { supabase } from '@/lib/supabase';
import { Conversation, Message, User } from '@/types';
import { toast } from 'sonner';

interface AuthState {
  user: User | null;
  session: Session | null;
  loading: boolean;
  isAuthenticated: boolean;
}

interface ConversationsState {
  list: Conversation[];
  active: Conversation | null;
  loading: boolean;
  searchQuery: string;
}

interface MessagesState {
  byConversationId: Record<string, Message[]>;
  sending: boolean;
  error: string | null;
}

interface UIState {
  sidebarOpen: boolean;
  uploadModalOpen: boolean;
  uploadFile: File | null;
  voiceMuted: boolean;
}

interface Store {
  auth: AuthState;
  conversations: ConversationsState;
  messages: MessagesState;
  ui: UIState;

  setUser: (user: User | null, session: Session | null) => void;
  logout: () => Promise<void>;
  loadConversations: () => Promise<void>;
  selectConversation: (id: string) => Promise<void>;
  createConversation: (title?: string) => Promise<Conversation | null>;
  deleteConversation: (id: string) => Promise<void>;
  updateConversationTitle: (id: string, title: string) => Promise<void>;
  sendMessage: (content: string, files?: File[]) => Promise<void>;
  loadMessages: (conversationId: string) => Promise<void>;
  setSearchQuery: (query: string) => void;
  toggleSidebar: () => void;
  setUploadModal: (open: boolean, file?: File) => void;
  regenerateMessage: (messageId: string) => Promise<void>;
  toggleVoiceMute: () => void;
}

export const useStore = create<Store>((set, get) => ({
  auth: {
    user: null,
    session: null,
    loading: true,
    isAuthenticated: false,
  },
  conversations: {
    list: [],
    active: null,
    loading: false,
    searchQuery: '',
  },
  messages: {
    byConversationId: {},
    sending: false,
    error: null,
  },
  ui: {
    sidebarOpen: false,
    uploadModalOpen: false,
    uploadFile: null,
    voiceMuted: typeof localStorage !== 'undefined'
      ? localStorage.getItem('voiceMuted') === 'true'
      : false,
  },

  setUser: (user, session) => {
    set({
      auth: {
        user,
        session,
        loading: false,
        isAuthenticated: !!user,
      },
    });
  },

  logout: async () => {
    await supabase.auth.signOut();
    set({
      auth: {
        user: null,
        session: null,
        loading: false,
        isAuthenticated: false,
      },
      conversations: {
        list: [],
        active: null,
        loading: false,
        searchQuery: '',
      },
      messages: {
        byConversationId: {},
        sending: false,
        error: null,
      },
    });
  },

  loadConversations: async () => {
    const { auth } = get();
    if (!auth.isAuthenticated) return;

    set((state) => ({
      conversations: { ...state.conversations, loading: true },
    }));

    const { data, error } = await supabase
      .from('aria_conversations')
      .select('*')
      .order('updated_at', { ascending: false });

    if (error) {
      console.error('Error loading conversations:', error);
      toast.error('Failed to load conversations');
      set((state) => ({
        conversations: { ...state.conversations, loading: false },
      }));
      return;
    }

    set((state) => ({
      conversations: { ...state.conversations, list: data || [], loading: false },
    }));
  },

  selectConversation: async (id: string) => {
    const { conversations } = get();
    const conversation = conversations.list.find((c) => c.id === id);

    if (conversation) {
      set((state) => ({
        conversations: { ...state.conversations, active: conversation },
      }));

      await get().loadMessages(id);
    }
  },

  createConversation: async (title = 'New Conversation') => {
    const { auth } = get();
    if (!auth.user) return null;

    const { data, error } = await supabase
      .from('aria_conversations')
      .insert({
        user_id: auth.user.id,
        title,
      })
      .select()
      .single();

    if (error) {
      console.error('Error creating conversation:', error);
      toast.error('Failed to create conversation');
      return null;
    }

    set((state) => ({
      conversations: {
        ...state.conversations,
        list: [data, ...state.conversations.list],
        active: data,
      },
    }));

    return data;
  },

  deleteConversation: async (id: string) => {
    const { error } = await supabase
      .from('aria_conversations')
      .delete()
      .eq('id', id);

    if (error) {
      console.error('Error deleting conversation:', error);
      toast.error('Failed to delete conversation');
      return;
    }

    set((state) => ({
      conversations: {
        ...state.conversations,
        list: state.conversations.list.filter((c) => c.id !== id),
        active: state.conversations.active?.id === id ? null : state.conversations.active,
      },
      messages: {
        ...state.messages,
        byConversationId: Object.fromEntries(
          Object.entries(state.messages.byConversationId).filter(([key]) => key !== id)
        ),
      },
    }));

    toast.success('Conversation deleted');
  },

  updateConversationTitle: async (id: string, title: string) => {
    const { error } = await supabase
      .from('aria_conversations')
      .update({ title, updated_at: new Date().toISOString() })
      .eq('id', id);

    if (error) {
      console.error('Error updating conversation:', error);
      toast.error('Failed to update title');
      return;
    }

    set((state) => ({
      conversations: {
        ...state.conversations,
        list: state.conversations.list.map((c) =>
          c.id === id ? { ...c, title, updated_at: new Date().toISOString() } : c
        ),
        active: state.conversations.active?.id === id
          ? { ...state.conversations.active, title }
          : state.conversations.active,
      },
    }));
  },

  loadMessages: async (conversationId: string) => {
    const { data: messages, error: messagesError } = await supabase
      .from('aria_messages')
      .select('*')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: true });

    if (messagesError) {
      console.error('Error loading messages:', messagesError);
      toast.error('Failed to load messages');
      return;
    }

    const { data: files, error: filesError } = await supabase
      .from('aria_attachments')
      .select('*')
      .in('message_id', messages?.map((m) => m.id) || []);

    if (filesError) {
      console.error('Error loading files:', filesError);
    }

    const messagesWithFiles = messages?.map((msg) => ({
      ...msg,
      files: files?.filter((f) => f.message_id === msg.id) || [],
    })) || [];

    set((state) => ({
      messages: {
        ...state.messages,
        byConversationId: {
          ...state.messages.byConversationId,
          [conversationId]: messagesWithFiles,
        },
      },
    }));
  },

  sendMessage: async (content: string, files?: File[]) => {
    const { conversations, auth } = get();
    if (!auth.user) return;

    let conversationId = conversations.active?.id;

    if (!conversationId) {
      const newConversation = await get().createConversation();
      if (!newConversation) return;
      conversationId = newConversation.id;
    }

    set((state) => ({
      messages: { ...state.messages, sending: true, error: null },
    }));

    const { data: userMessage, error: messageError } = await supabase
      .from('aria_messages')
      .insert({
        conversation_id: conversationId,
        role: 'user',
        content,
      })
      .select()
      .single();

    if (messageError) {
      console.error('Error sending message:', messageError);
      toast.error('Failed to send message');
      set((state) => ({
        messages: { ...state.messages, sending: false, error: messageError.message },
      }));
      return;
    }

    if (files && files.length > 0) {
      for (const file of files) {
        const filePath = `${auth.user.id}/${Date.now()}-${file.name}`;
        const { error: uploadError } = await supabase.storage
          .from('chat-files')
          .upload(filePath, file);

        if (uploadError) {
          console.error('Error uploading file:', uploadError);
          continue;
        }

        await supabase.from('aria_attachments').insert({
          message_id: userMessage.id,
          filename: file.name,
          storage_path: filePath,
          file_size: file.size,
          file_type: file.type,
        });
      }
    }

    await get().loadMessages(conversationId);

    if (conversations.list.length === 0 || !conversations.active) {
      const title = content.slice(0, 50) + (content.length > 50 ? '...' : '');
      await get().updateConversationTitle(conversationId, title);
    }

    await supabase
      .from('aria_conversations')
      .update({ updated_at: new Date().toISOString() })
      .eq('id', conversationId);

    // Call ARIA AI backend
    let aiResponse = '';
    try {
      const response = await fetch('https://hooks.leveredgeai.com/webhook/aria', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: content,
          conversation_id: conversationId,
          user_id: auth.user.id,
          interface_source: 'web',
        }),
      });

      if (!response.ok) {
        throw new Error(`API returned ${response.status}`);
      }

      const data = await response.json();
      aiResponse = data.response || data.message || 'Sorry, I encountered an error processing your request.';
    } catch (error) {
      console.error('Error calling ARIA API:', error);
      aiResponse = 'Sorry, I\'m having trouble connecting to my AI backend. Please try again.';
    }
    await new Promise((resolve) => setTimeout(resolve, 1000));

    const { error: aiError } = await supabase
      .from('aria_messages')
      .insert({
        conversation_id: conversationId,
        role: 'assistant',
        content: aiResponse,
      })
      .select()
      .single();

    if (aiError) {
      console.error('Error creating AI response:', aiError);
    }

    await get().loadMessages(conversationId);
    await get().loadConversations();

    set((state) => ({
      messages: { ...state.messages, sending: false },
    }));
  },

  regenerateMessage: async () => {
    toast.info('Regenerating response...');
  },

  setSearchQuery: (query: string) => {
    set((state) => ({
      conversations: { ...state.conversations, searchQuery: query },
    }));
  },

  toggleSidebar: () => {
    set((state) => ({
      ui: { ...state.ui, sidebarOpen: !state.ui.sidebarOpen },
    }));
  },

  setUploadModal: (open: boolean, file?: File) => {
    set((state) => ({
      ui: { ...state.ui, uploadModalOpen: open, uploadFile: file || null },
    }));
  },

  toggleVoiceMute: () => {
    set((state) => {
      const newMuted = !state.ui.voiceMuted;
      if (typeof localStorage !== 'undefined') {
        localStorage.setItem('voiceMuted', String(newMuted));
      }
      return {
        ui: { ...state.ui, voiceMuted: newMuted },
      };
    });
  },
}));
