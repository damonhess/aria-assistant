import { useEffect } from 'react';
import { useStore } from '@/store/useStore';
import { Header } from '@/components/chat/Header';
import { Sidebar } from '@/components/chat/Sidebar';
import { ChatArea } from '@/components/chat/ChatArea';
import { MessageInput } from '@/components/chat/MessageInput';

export function Chat() {
  const { loadConversations, auth } = useStore();

  useEffect(() => {
    if (auth.isAuthenticated) {
      loadConversations();
    }
  }, [auth.isAuthenticated]);

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <Sidebar />

      <div className="flex-1 flex flex-col">
        <Header />

        <div className="flex-1 overflow-hidden flex flex-col">
          <ChatArea />
          <MessageInput />
        </div>
      </div>
    </div>
  );
}
