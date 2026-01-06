import { motion } from 'framer-motion';
import { Message } from '@/types';
import { cn } from '@/lib/utils';
import { Copy, RefreshCw, Check, Volume2, VolumeX } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useState } from 'react';
import { MarkdownRenderer } from './MarkdownRenderer';
import { formatDistanceToNow } from 'date-fns';
import { MessageAttachment } from './MessageAttachment';
import { useSpeechSynthesis } from '@/hooks/useSpeechSynthesis';
import { useStore } from '@/store/useStore';

interface MessageBubbleProps {
  message: Message;
  index: number;
}

export function MessageBubble({ message, index }: MessageBubbleProps) {
  const [copied, setCopied] = useState(false);
  const [showActions, setShowActions] = useState(false);
  const [isSpeakingThis, setIsSpeakingThis] = useState(false);
  const { speak, stop } = useSpeechSynthesis();
  const { ui } = useStore();

  const isUser = message.role === 'user';

  const handleCopy = async () => {
    await navigator.clipboard.writeText(message.content);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleSpeak = () => {
    if (ui.voiceMuted) return;

    if (isSpeakingThis) {
      stop();
      setIsSpeakingThis(false);
    } else {
      stop();
      speak(message.content);
      setIsSpeakingThis(true);
      setTimeout(() => setIsSpeakingThis(false), message.content.length * 50);
    }
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      transition={{ delay: index * 0.05 }}
      className={cn('flex', isUser ? 'justify-end' : 'justify-start')}
      onMouseEnter={() => setShowActions(true)}
      onMouseLeave={() => setShowActions(false)}
    >
      <div
        className={cn(
          'max-w-[85%] lg:max-w-[75%] rounded-2xl px-4 py-3 shadow-lg',
          isUser
            ? 'bg-gradient-to-br from-blue-600 to-blue-500 text-white'
            : 'bg-zinc-800 dark:bg-zinc-800 border border-zinc-700'
        )}
      >
        <div className="prose prose-sm dark:prose-invert max-w-none">
          {isUser ? (
            <p className="whitespace-pre-wrap text-white m-0">{message.content}</p>
          ) : (
            <MarkdownRenderer content={message.content} />
          )}
        </div>

        {message.files && message.files.length > 0 && (
          <div className="mt-3 space-y-2">
            {message.files.map((file) => (
              <MessageAttachment key={file.id} file={file} />
            ))}
          </div>
        )}

        {showActions && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            className={cn(
              'flex items-center gap-1 mt-2 pt-2 border-t',
              isUser ? 'border-white/20' : 'border-zinc-700'
            )}
          >
            <Button
              variant="ghost"
              size="sm"
              onClick={handleCopy}
              className={cn(
                'h-7 px-2 text-xs',
                isUser
                  ? 'text-white hover:bg-white/10'
                  : 'text-muted-foreground hover:bg-zinc-700'
              )}
            >
              {copied ? (
                <Check className="h-3 w-3 mr-1" />
              ) : (
                <Copy className="h-3 w-3 mr-1" />
              )}
              {copied ? 'Copied' : 'Copy'}
            </Button>

            {!isUser && (
              <>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={handleSpeak}
                  className="h-7 px-2 text-xs text-muted-foreground hover:bg-zinc-700"
                  disabled={ui.voiceMuted}
                >
                  {isSpeakingThis ? (
                    <VolumeX className="h-3 w-3 mr-1" />
                  ) : (
                    <Volume2 className="h-3 w-3 mr-1" />
                  )}
                  {isSpeakingThis ? 'Stop' : 'Speak'}
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  className="h-7 px-2 text-xs text-muted-foreground hover:bg-zinc-700"
                >
                  <RefreshCw className="h-3 w-3 mr-1" />
                  Regenerate
                </Button>
              </>
            )}

            <span
              className={cn(
                'ml-auto text-xs',
                isUser ? 'text-white/70' : 'text-muted-foreground'
              )}
            >
              {formatDistanceToNow(new Date(message.created_at), {
                addSuffix: true,
              })}
            </span>
          </motion.div>
        )}
      </div>
    </motion.div>
  );
}
