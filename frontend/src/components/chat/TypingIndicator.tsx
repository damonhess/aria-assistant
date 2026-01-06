import { motion } from 'framer-motion';

export function TypingIndicator() {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="flex justify-start"
    >
      <div className="max-w-[75%] rounded-2xl px-4 py-3 bg-zinc-800 border border-zinc-700 shadow-lg">
        <div className="flex items-center gap-2">
          <div className="flex gap-1">
            {[0, 1, 2].map((i) => (
              <motion.div
                key={i}
                animate={{
                  y: [0, -8, 0],
                }}
                transition={{
                  duration: 0.6,
                  repeat: Infinity,
                  delay: i * 0.1,
                }}
                className="w-2 h-2 bg-blue-500 rounded-full"
              />
            ))}
          </div>
          <span className="text-sm text-muted-foreground ml-2">
            ARIA is thinking...
          </span>
        </div>
      </div>
    </motion.div>
  );
}
