import { useState, useEffect, useRef } from 'react';

interface UseSpeechRecognitionReturn {
  isListening: boolean;
  transcript: string;
  startListening: () => void;
  stopListening: () => void;
  resetTranscript: () => void;
  isSupported: boolean;
  error: string | null;
}

export function useSpeechRecognition(): UseSpeechRecognitionReturn {
  const [isListening, setIsListening] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [error, setError] = useState<string | null>(null);
  const recognitionRef = useRef<SpeechRecognition | null>(null);

  const isSupported = 'webkitSpeechRecognition' in window || 'SpeechRecognition' in window;

  useEffect(() => {
    if (!isSupported) {
      setError('Speech recognition is not supported in this browser');
      return;
    }

    const SpeechRecognitionAPI =
      (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;

    const recognition = new SpeechRecognitionAPI();
    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.lang = 'en-US';

    recognition.onresult = (event: SpeechRecognitionEvent) => {
      let interimTranscript = '';
      let finalTranscript = '';

      for (let i = event.resultIndex; i < event.results.length; i++) {
        const transcriptPiece = event.results[i][0].transcript;
        if (event.results[i].isFinal) {
          finalTranscript += transcriptPiece + ' ';
        } else {
          interimTranscript += transcriptPiece;
        }
      }

      setTranscript((prev) => {
        const withoutInterim = prev.split('~~~INTERIM~~~')[0];
        if (finalTranscript) {
          return withoutInterim + finalTranscript;
        }
        return withoutInterim + '~~~INTERIM~~~' + interimTranscript;
      });
    };

    recognition.onerror = (event: SpeechRecognitionErrorEvent) => {
      console.error('Speech recognition error:', event.error);
      setError(`Speech recognition error: ${event.error}`);
      setIsListening(false);
    };

    recognition.onend = () => {
      setIsListening(false);
    };

    recognitionRef.current = recognition;

    return () => {
      if (recognitionRef.current) {
        recognitionRef.current.stop();
      }
    };
  }, [isSupported]);

  const startListening = () => {
    if (!recognitionRef.current || isListening) return;

    setError(null);
    try {
      recognitionRef.current.start();
      setIsListening(true);
    } catch (err) {
      console.error('Error starting recognition:', err);
      setError('Failed to start speech recognition');
    }
  };

  const stopListening = () => {
    if (!recognitionRef.current || !isListening) return;

    try {
      recognitionRef.current.stop();
      setIsListening(false);
      setTranscript((prev) => prev.split('~~~INTERIM~~~')[0]);
    } catch (err) {
      console.error('Error stopping recognition:', err);
    }
  };

  const resetTranscript = () => {
    setTranscript('');
    setError(null);
  };

  const displayTranscript = transcript.split('~~~INTERIM~~~')[0];

  return {
    isListening,
    transcript: displayTranscript,
    startListening,
    stopListening,
    resetTranscript,
    isSupported,
    error,
  };
}
