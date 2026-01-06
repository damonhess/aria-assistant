import { useEffect, useState } from 'react';
import { Navigate } from 'react-router-dom';
import { useStore } from '@/store/useStore';
import { supabase } from '@/lib/supabase';
import { motion } from 'framer-motion';
import { Sparkles } from 'lucide-react';

export function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { auth, setUser } = useStore();
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    const checkSession = async () => {
      const { data: { session } } = await supabase.auth.getSession();

      if (session?.user) {
        setUser(
          {
            id: session.user.id,
            email: session.user.email!,
            created_at: session.user.created_at,
          },
          session
        );
      }

      setChecking(false);
    };

    checkSession();

    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (_event, session) => {
        if (session?.user) {
          setUser(
            {
              id: session.user.id,
              email: session.user.email!,
              created_at: session.user.created_at,
            },
            session
          );
        } else {
          setUser(null, null);
        }
      }
    );

    return () => {
      subscription.unsubscribe();
    };
  }, [setUser]);

  if (checking || auth.loading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-background">
        <motion.div
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: 1, scale: 1 }}
          className="text-center"
        >
          <motion.div
            animate={{ rotate: 360 }}
            transition={{ duration: 2, repeat: Infinity, ease: 'linear' }}
            className="inline-block mb-4"
          >
            <Sparkles className="h-12 w-12 text-blue-500" />
          </motion.div>
          <p className="text-lg text-muted-foreground">Loading ARIA...</p>
        </motion.div>
      </div>
    );
  }

  if (!auth.isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
}
