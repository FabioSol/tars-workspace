import * as React from "react";
import { cn } from "@/lib/utils";

interface AnimatedContainerProps extends React.HTMLAttributes<HTMLDivElement> {
  /** GSAP animation to apply on mount — handle in consumer with useGSAP */
  children: React.ReactNode;
}

const AnimatedContainer = React.forwardRef<HTMLDivElement, AnimatedContainerProps>(
  ({ className, children, ...props }, ref) => {
    return (
      <div ref={ref} className={cn("will-change-transform", className)} {...props}>
        {children}
      </div>
    );
  }
);

AnimatedContainer.displayName = "AnimatedContainer";

export { AnimatedContainer };
export type { AnimatedContainerProps };
