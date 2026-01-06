import { X, File, Image as ImageIcon, FileText, Music, Video } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

interface FilePreviewProps {
  file: File;
  onRemove: () => void;
}

export function FilePreview({ file, onRemove }: FilePreviewProps) {
  const isImage = file.type.startsWith('image/');
  const isVideo = file.type.startsWith('video/');
  const isAudio = file.type.startsWith('audio/');
  const isPDF = file.type === 'application/pdf';

  const fileUrl = isImage ? URL.createObjectURL(file) : null;

  const getFileIcon = () => {
    if (isVideo) return <Video className="h-8 w-8" />;
    if (isAudio) return <Music className="h-8 w-8" />;
    if (isPDF) return <FileText className="h-8 w-8" />;
    if (isImage) return <ImageIcon className="h-8 w-8" />;
    return <File className="h-8 w-8" />;
  };

  const formatFileSize = (bytes: number) => {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  };

  return (
    <div className="relative group">
      <div
        className={cn(
          'rounded-lg border border-border overflow-hidden bg-muted',
          'flex items-center justify-center',
          isImage ? 'w-24 h-24' : 'w-full p-3'
        )}
      >
        {isImage && fileUrl ? (
          <img
            src={fileUrl}
            alt={file.name}
            className="w-full h-full object-cover"
          />
        ) : (
          <div className="flex items-center gap-2 text-muted-foreground">
            {getFileIcon()}
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium truncate">{file.name}</p>
              <p className="text-xs text-muted-foreground">{formatFileSize(file.size)}</p>
            </div>
          </div>
        )}
      </div>
      <Button
        variant="destructive"
        size="icon"
        className="absolute -top-2 -right-2 h-6 w-6 rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
        onClick={onRemove}
      >
        <X className="h-4 w-4" />
      </Button>
    </div>
  );
}
