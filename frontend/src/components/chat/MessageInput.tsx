import { useState, useRef, KeyboardEvent, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Send, X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { useStore } from '@/store/useStore';
import { cn } from '@/lib/utils';
import { FileUploadButton } from './FileUploadButton';
import { VoiceRecordButton } from './VoiceRecordButton';
import { FilePreview } from './FilePreview';
import { useSpeechRecognition } from '@/hooks/useSpeechRecognition';
import { toast } from 'sonner';

export function MessageInput() {
  const [message, setMessage] = useState('');
  const [selectedFiles, setSelectedFiles] = useState<File[]>([]);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const { sendMessage, messages } = useStore();
  const {
    isListening,
    transcript,
    startListening,
    stopListening,
    resetTranscript,
    isSupported: speechSupported,
  } = useSpeechRecognition();

  useEffect(() => {
    if (transcript) {
      setMessage((prev) => {
        const newText = prev + (prev ? ' ' : '') + transcript;
        return newText;
      });
      resetTranscript();
    }
  }, [transcript]);

  const handleSend = async () => {
    if ((!message.trim() && selectedFiles.length === 0) || messages.sending) return;

    const content = message.trim() || 'Sent attachment(s)';
    setMessage('');

    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
    }

    const files = selectedFiles;
    setSelectedFiles([]);

    await sendMessage(content, files.length > 0 ? files : undefined);
  };

  const handleFilesSelected = (files: File[]) => {
    setSelectedFiles((prev) => [...prev, ...files]);
    toast.success(`${files.length} file(s) selected`);
  };

  const handleRemoveFile = (index: number) => {
    setSelectedFiles((prev) => prev.filter((_, i) => i !== index));
  };

  const handleVoiceRecord = () => {
    if (!speechSupported) {
      toast.error('Speech recognition is not supported in this browser');
      return;
    }

    if (isListening) {
      stopListening();
    } else {
      startListening();
      toast.info('Listening... Speak now');
    }
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const handleInput = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setMessage(e.target.value);

    e.target.style.height = 'auto';
    const newHeight = Math.min(e.target.scrollHeight, 120);
    e.target.style.height = `${newHeight}px`;
  };

  return (
    <div className="border-t border-border/50 bg-background/80 backdrop-blur-xl" style={{ paddingBottom: 'env(safe-area-inset-bottom)' }}>
      <div className="max-w-4xl mx-auto px-4 lg:px-6 py-4">
        <AnimatePresence>
          {selectedFiles.length > 0 && (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 10 }}
              className="mb-3 p-3 rounded-xl bg-card/50 border border-border/50"
            >
              <div className="flex items-center justify-between mb-2">
                <p className="text-sm font-medium">
                  {selectedFiles.length} file(s) selected
                </p>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setSelectedFiles([])}
                  className="h-6 px-2"
                >
                  <X className="h-4 w-4" />
                </Button>
              </div>
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-2">
                {selectedFiles.map((file, index) => (
                  <FilePreview
                    key={index}
                    file={file}
                    onRemove={() => handleRemoveFile(index)}
                  />
                ))}
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        <motion.div
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          className="relative flex items-end gap-2 p-3 rounded-2xl bg-card/50 border border-border/50 shadow-lg"
        >
          <div className="flex items-end gap-1">
            <FileUploadButton
              onFilesSelected={handleFilesSelected}
              disabled={messages.sending}
            />
            <VoiceRecordButton
              isRecording={isListening}
              onStartRecording={handleVoiceRecord}
              onStopRecording={handleVoiceRecord}
              disabled={messages.sending}
            />
          </div>

          <Textarea
            ref={textareaRef}
            value={message}
            onChange={handleInput}
            onKeyDown={handleKeyDown}
            placeholder={
              isListening ? 'Listening...' : 'Message ARIA...'
            }
            className={cn(
              'min-h-[44px] max-h-[120px] resize-none border-0 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0 px-0 text-base',
              'scrollbar-thin scrollbar-thumb-zinc-700 scrollbar-track-transparent',
              isListening && 'text-red-500'
            )}
            disabled={messages.sending}
            rows={1}
          />

          <Button
            onClick={handleSend}
            disabled={(!message.trim() && selectedFiles.length === 0) || messages.sending}
            className={cn(
              'flex-shrink-0 mb-1 bg-gradient-to-r from-blue-600 to-blue-500 hover:from-blue-700 hover:to-blue-600 text-white shadow-lg transition-all',
              ((!message.trim() && selectedFiles.length === 0) || messages.sending) && 'opacity-50 cursor-not-allowed'
            )}
            size="icon"
          >
            <motion.div
              animate={messages.sending ? { rotate: 360 } : {}}
              transition={messages.sending ? { duration: 1, repeat: Infinity, ease: 'linear' } : {}}
            >
              <Send className="h-5 w-5" />
            </motion.div>
          </Button>
        </motion.div>

        <p className="text-xs text-muted-foreground text-center mt-2">
          Press Enter to send, Shift+Enter for new line
        </p>
      </div>
    </div>
  );
}
