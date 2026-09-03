import { Link } from "@tanstack/react-router";

const LINKS = [
  { to: "/", label: "الرئيسية" },
  { to: "/talameed", label: "فضاء التلاميذ" },
  { to: "/taleem", label: "فضاء التعليم" },
  { to: "/admin", label: "فضاء الإدارة" },
] as const;

export function SiteFooter() {
  const year = new Date().getFullYear();

  return (
    <footer className="mt-auto border-t border-border/60 bg-background/70 backdrop-blur">
      <div className="mx-auto flex w-full max-w-5xl flex-col items-center gap-4 px-4 py-6 text-sm sm:flex-row sm:justify-between">
        <nav aria-label="روابط الموقع" className="flex flex-wrap items-center justify-center gap-4">
          {LINKS.map((link) => (
            <Link
              key={link.to}
              to={link.to}
              className="text-muted-foreground transition-colors hover:text-foreground"
            >
              {link.label}
            </Link>
          ))}
        </nav>
        <p className="text-muted-foreground">© {year} مداوروس — Madauros. جميع الحقوق محفوظة.</p>
      </div>
    </footer>
  );
}
