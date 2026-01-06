import { Download, File, Image as ImageIcon, FileText, Music, Video } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { FileAttachment } from '@/types';
import { supabase } from '@/lib/supabase';
import { useState } from 'react';
import { Dialog, DialogContent } from '@/components/ui/dialog';

interface MessageAttachmentProps {
  file: FileAttachment;
}

export function MessageAttachment({ file }: MessageAttachmentProps) {
  const [imageOpen, setImageOpen] = useState(false);
  const [imageUrl, setImageUrl] = useState<string | null>(null);

  const isImage = file.file_type.startsWith('image/');
  const isVideo = file.file_type.startsWith('video/');
  const isAudio = file.file_type.startsWith('audio/');
  const isPDF = file.file_type === 'application/pdf';

  const getFileIcon = () => {
    if (isVideo) return <Video className="h-4 w-4" />;
    if (isAudio) return <Music className="h-4 w-4" />;
    if (isPDF) return <FileText className="h-4 w-4" />;
    if (isImage) return <ImageIcon className="h-4 w-4" />;
    return <File className="h-4 w-4" />;
  };

  const formatFileSize = (bytes: number) => {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  };

  const handleDownload = async () => {
    const { data } = await supabase.storage
      .from('chat-files')
      .download(file.file_path);

    if (data) {
      const url = URL.createObjectURL(data);
      const a = document.createElement('a');
      a.href = url;
      a.download = file.filename;
      a.click();
      URL.revokeObjectURL(url);
    }
  };

  const handleImageClick = async () => {
    if (!isImage) return;

    const { data } = await supabase.storage
      .from('chat-files')
      .getPublicUrl(file.file_path);

    setImageUrl(data.publicUrl);
    setImageOpen(true);
  };

  if (isImage) {
    return (
      <>
        <div
          className="relative rounded-lg overflow-hidden cursor-pointer group max-w-xs"
          onClick={handleImageClick}
        >
          <img
            src={supabase.storage.from('chat-files').getPublicUrl(file.file_path).data.publicUrl}
            alt={file.filename}
            className="w-full h-auto max-h-64 object-cover"
          />
          <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
            <Button variant="secondary" size="sm" onClick={handleDownload}>
              <Download className="h-4 w-4 mr-2" />
              Download
            </Button>
          </div>
        </div>
        <Dialog open={imageOpen} onOpenChange={setImageOpen}>
          <DialogContent className="max-w-4xl">
            {imageUrl && (
              <img src={imageUrl} alt={file.filename} className="w-full h-auto" />
            )}
          </DialogContent>
        </Dialog>
      </>
    );
  }

  return (
    <div className="flex items-center gap-2 p-2 rounded-lg bg-muted/50 border border-border max-w-xs">
      <div className="text-muted-foreground">{getFileIcon()}</div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium truncate">{file.filename}</p>
        <p className="text-xs text-muted-foreground">{formatFileSize(file.file_size)}</p>
      </div>
      <Button variant="ghost" size="sm" onClick={handleDownload}>
        <Download className="h-4 w-4" />
      </Button>
    </div>
  );
}
