import { useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useStore } from '@/store/useStore';
import { MessageBubble } from './MessageBubble';
import { TypingIndicator } from './TypingIndicator';
import { MessageSquarePlus } from 'lucide-react';

export function ChatArea() {
  const { conversations, messages } = useStore();
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const currentMessages = conversations.active
    ? messages.byConversationId[conversations.active.id] || []
    : [];

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [currentMessages, messages.sending]);

  if (!conversations.active) {
    return (
      <div className="flex-1 flex items-center justify-center px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center max-w-md"
        >
          <motion.div
            animate={{
              rotate: 360,
              scale: [1, 1.1, 1],
            }}
            transition={{
              rotate: { duration: 20, repeat: Infinity, ease: 'linear' },
              scale: { duration: 2, repeat: Infinity },
            }}
            className="inline-block mb-6"
          >
            <MessageSquarePlus className="h-20 w-20 text-blue-500/50" />
          </motion.div>
          <h2 className="text-2xl font-bold mb-3">Welcome to ARIA</h2>
          <p className="text-muted-foreground mb-6">
            Your Personal AI Operating System. Start a new conversation or select
            an existing one from the sidebar.
          </p>
          <div className="grid grid-cols-1 gap-3 text-sm">
            <div className="p-4 rounded-lg bg-card/50 border border-border/50 text-left">
              <div className="font-medium mb-1">💬 Natural Conversations</div>
              <div className="text-muted-foreground">
                Have intelligent discussions with advanced AI
              </div>
            </div>
            <div className="p-4 rounded-lg bg-card/50 border border-border/50 text-left">
              <div className="font-medium mb-1">📁 File Support</div>
              <div className="text-muted-foreground">
                Upload and analyze documents, images, and more
              </div>
            </div>
            <div className="p-4 rounded-lg bg-card/50 border border-border/50 text-left">
              <div className="font-medium mb-1">✨ Beautiful Interface</div>
              <div className="text-muted-foreground">
                Enjoy a premium, production-grade experience
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    );
  }

  return (
    <div className="flex-1 overflow-y-auto px-4 lg:px-6 py-6">
      <div className="max-w-4xl mx-auto space-y-4">
        <AnimatePresence mode="popLayout">
          {currentMessages.map((message, index) => (
            <MessageBubble
              key={message.id}
              message={message}
              index={index}
            />
          ))}
        </AnimatePresence>

        {messages.sending && <TypingIndicator />}

        <div ref={messagesEndRef} />
      </div>
    </div>
  );
}
