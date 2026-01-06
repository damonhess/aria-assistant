import { motion } from 'framer-motion';
import { Mic, MicOff } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

interface VoiceRecordButtonProps {
  isRecording: boolean;
  onStartRecording: () => void;
  onStopRecording: () => void;
  disabled?: boolean;
}

export function VoiceRecordButton({
  isRecording,
  onStartRecording,
  onStopRecording,
  disabled,
}: VoiceRecordButtonProps) {
  return (
    <Button
      variant="ghost"
      size="icon"
      onClick={isRecording ? onStopRecording : onStartRecording}
      disabled={disabled}
      className={cn(
        'shrink-0 relative',
        isRecording && 'text-red-500 hover:text-red-600'
      )}
    >
      {isRecording ? (
        <>
          <motion.div
            className="absolute inset-0 rounded-full bg-red-500/20"
            animate={{
              scale: [1, 1.3, 1],
              opacity: [0.5, 0.2, 0.5],
            }}
            transition={{
              duration: 1.5,
              repeat: Infinity,
              ease: "easeInOut",
            }}
          />
          <MicOff className="h-5 w-5 relative z-10" />
        </>
      ) : (
        <Mic className="h-5 w-5" />
      )}
    </Button>
  );
}
