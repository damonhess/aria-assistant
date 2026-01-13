import { motion, AnimatePresence } from 'framer-motion';
import { Plus, Search, Trash2, MessageSquare } from 'lucide-react';
import { useStore } from '@/store/useStore';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { formatDistanceToNow } from 'date-fns';
import { cn } from '@/lib/utils';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { useState } from 'react';

export function Sidebar() {
  const {
    ui,
    toggleSidebar,
    conversations,
    createConversation,
    selectConversation,
    deleteConversation,
    setSearchQuery,
  } = useStore();
  const [deleteId, setDeleteId] = useState<string | null>(null);

  const handleNewChat = async () => {
    await createConversation();
  };

  const handleDeleteClick = (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    setDeleteId(id);
  };

  const handleDeleteConfirm = async () => {
    if (deleteId) {
      await deleteConversation(deleteId);
      setDeleteId(null);
    }
  };

  const filteredConversations = conversations.list.filter((conv) =>
    conv.title.toLowerCase().includes(conversations.searchQuery.toLowerCase())
  );

  const groupedConversations = {
    today: [] as typeof conversations.list,
    yesterday: [] as typeof conversations.list,
    lastWeek: [] as typeof conversations.list,
    older: [] as typeof conversations.list,
  };

  filteredConversations.forEach((conv) => {
    const date = new Date(conv.updated_at);
    const now = new Date();
    const diffDays = Math.floor((now.getTime() - date.getTime()) / (1000 * 60 * 60 * 24));

    if (diffDays === 0) {
      groupedConversations.today.push(conv);
    } else if (diffDays === 1) {
      groupedConversations.yesterday.push(conv);
    } else if (diffDays <= 7) {
      groupedConversations.lastWeek.push(conv);
    } else {
      groupedConversations.older.push(conv);
    }
  });

  const sidebarContent = (
    <motion.div
      initial={false}
      animate={{ x: 0 }}
      exit={{ x: -280 }}
      transition={{ type: 'spring', damping: 25, stiffness: 200 }}
      className="w-[85vw] max-w-80 h-full bg-card/30 backdrop-blur-xl border-r border-border/50 flex flex-col"
    >
      <div className="p-4 space-y-4">
        <Button
          onClick={handleNewChat}
          className="w-full bg-gradient-to-r from-blue-600 to-blue-500 hover:from-blue-700 hover:to-blue-600 text-white shadow-lg"
        >
          <Plus className="mr-2 h-4 w-4" />
          New Chat
        </Button>

        <div className="relative">
          <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search conversations..."
            className="pl-10 bg-background/50"
            value={conversations.searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-2">
        {conversations.list.length === 0 ? (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="flex flex-col items-center justify-center h-full px-4 text-center"
          >
            <MessageSquare className="h-16 w-16 text-muted-foreground/50 mb-4" />
            <h3 className="font-medium mb-2">No conversations yet</h3>
            <p className="text-sm text-muted-foreground">
              Start a new conversation to begin
            </p>
          </motion.div>
        ) : (
          <div className="space-y-6 py-2">
            {Object.entries(groupedConversations).map(([key, convs]) =>
              convs.length > 0 ? (
                <div key={key}>
                  <h3 className="px-3 mb-2 text-xs font-semibold text-muted-foreground uppercase">
                    {key === 'today' && 'Today'}
                    {key === 'yesterday' && 'Yesterday'}
                    {key === 'lastWeek' && 'Last 7 days'}
                    {key === 'older' && 'Older'}
                  </h3>
                  <div className="space-y-1">
                    {convs.map((conv) => (
                      <motion.button
                        key={conv.id}
                        initial={{ opacity: 0, x: -20 }}
                        animate={{ opacity: 1, x: 0 }}
                        exit={{ opacity: 0, x: -20 }}
                        whileHover={{ scale: 1.02 }}
                        whileTap={{ scale: 0.98 }}
                        onClick={() => selectConversation(conv.id)}
                        className={cn(
                          'w-full text-left p-3 rounded-lg transition-all group relative',
                          conversations.active?.id === conv.id
                            ? 'bg-blue-500/10 border-l-2 border-blue-500'
                            : 'hover:bg-accent'
                        )}
                      >
                        <div className="flex items-start justify-between gap-2">
                          <div className="flex-1 min-w-0">
                            <h4 className="font-medium text-sm truncate mb-1">
                              {conv.title}
                            </h4>
                            <p className="text-xs text-muted-foreground">
                              {formatDistanceToNow(new Date(conv.updated_at), {
                                addSuffix: true,
                              })}
                            </p>
                          </div>
                          <button
                            onClick={(e) => handleDeleteClick(e, conv.id)}
                            className="opacity-100 lg:opacity-0 lg:group-hover:opacity-100 transition-opacity p-1 -m-1"
                          >
                            <Trash2 className="h-4 w-4 text-muted-foreground hover:text-red-500" />
                          </button>
                        </div>
                      </motion.button>
                    ))}
                  </div>
                </div>
              ) : null
            )}
          </div>
        )}
      </div>
    </motion.div>
  );

  return (
    <>
      <div className="hidden lg:block">{sidebarContent}</div>

      <AnimatePresence>
        {ui.sidebarOpen && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={toggleSidebar}
              className="fixed inset-0 bg-background/80 backdrop-blur-sm z-40 lg:hidden"
            />
            <div className="fixed inset-y-0 left-0 z-50 lg:hidden">
              {sidebarContent}
            </div>
          </>
        )}
      </AnimatePresence>

      <AlertDialog open={!!deleteId} onOpenChange={() => setDeleteId(null)}>
        <AlertDialogContent className="backdrop-blur-xl bg-card/95">
          <AlertDialogHeader>
            <AlertDialogTitle>Delete conversation?</AlertDialogTitle>
            <AlertDialogDescription>
              This action cannot be undone. This will permanently delete the
              conversation and all its messages.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDeleteConfirm}
              className="bg-red-500 hover:bg-red-600"
            >
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}
