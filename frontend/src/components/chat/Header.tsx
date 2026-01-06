import { motion } from 'framer-motion';
import { Menu, Sparkles, Sun, Moon, LogOut, Settings, User, Volume2, VolumeX } from 'lucide-react';
import { useStore } from '@/store/useStore';
import { useTheme } from '@/providers/ThemeProvider';
import { Button } from '@/components/ui/button';
import { toast } from 'sonner';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';

export function Header() {
  const { theme, toggleTheme } = useTheme();
  const { toggleSidebar, conversations, auth, logout, ui, toggleVoiceMute } = useStore();

  const userInitials = auth.user?.email?.slice(0, 2).toUpperCase() || 'U';

  const handleToggleMute = () => {
    toggleVoiceMute();
    toast.success(ui.voiceMuted ? 'Voice unmuted' : 'Voice muted');
  };

  return (
    <motion.header
      initial={{ y: -20, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      className="h-16 border-b border-border/50 backdrop-blur-xl bg-background/80 flex items-center justify-between px-4 lg:px-6 sticky top-0 z-30"
    >
      <div className="flex items-center gap-4">
        <Button
          variant="ghost"
          size="icon"
          onClick={toggleSidebar}
          className="lg:hidden"
        >
          <Menu className="h-5 w-5" />
        </Button>

        <div className="flex items-center gap-2">
          <motion.div
            animate={{ rotate: 360 }}
            transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
          >
            <Sparkles className="w-6 h-6 text-blue-500" />
          </motion.div>
          <h1 className="text-xl font-bold bg-gradient-to-r from-blue-600 to-cyan-500 bg-clip-text text-transparent">
            ARIA
          </h1>
        </div>
      </div>

      <div className="flex-1 flex justify-center">
        <motion.h2
          key={conversations.active?.id}
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-sm font-medium text-muted-foreground max-w-md truncate"
        >
          {conversations.active?.title || 'New Conversation'}
        </motion.h2>
      </div>

      <div className="flex items-center gap-2">
        <Button
          variant="ghost"
          size="icon"
          onClick={handleToggleMute}
          className="relative"
        >
          <motion.div
            initial={false}
            animate={{ scale: ui.voiceMuted ? 1 : [1, 1.1, 1] }}
            transition={{ duration: 0.3, repeat: ui.voiceMuted ? 0 : Infinity, repeatDelay: 2 }}
          >
            {ui.voiceMuted ? (
              <VolumeX className="h-5 w-5 text-red-500" />
            ) : (
              <Volume2 className="h-5 w-5" />
            )}
          </motion.div>
        </Button>

        <Button
          variant="ghost"
          size="icon"
          onClick={toggleTheme}
          className="relative"
        >
          <motion.div
            initial={false}
            animate={{ rotate: theme === 'dark' ? 0 : 180 }}
            transition={{ duration: 0.3 }}
          >
            {theme === 'dark' ? (
              <Moon className="h-5 w-5" />
            ) : (
              <Sun className="h-5 w-5" />
            )}
          </motion.div>
        </Button>

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon" className="rounded-full">
              <Avatar className="h-8 w-8">
                <AvatarFallback className="bg-gradient-to-br from-blue-500 to-cyan-500 text-white text-xs">
                  {userInitials}
                </AvatarFallback>
              </Avatar>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-56 backdrop-blur-xl bg-card/95">
            <div className="px-2 py-1.5">
              <p className="text-sm font-medium">{auth.user?.email}</p>
            </div>
            <DropdownMenuSeparator />
            <DropdownMenuItem>
              <User className="mr-2 h-4 w-4" />
              <span>Profile</span>
            </DropdownMenuItem>
            <DropdownMenuItem>
              <Settings className="mr-2 h-4 w-4" />
              <span>Settings</span>
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem onClick={logout} className="text-red-500">
              <LogOut className="mr-2 h-4 w-4" />
              <span>Logout</span>
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </motion.header>
  );
}
