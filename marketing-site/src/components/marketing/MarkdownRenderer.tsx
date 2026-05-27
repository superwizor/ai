// Brand-themed markdown renderer.
//
// react-markdown lets us write legal content as plain .md files and
// render with React components — easier to review and translate than
// raw JSX, and the content stays free of layout concerns. remark-gfm
// pulls in tables / task-lists / autolinks (GDPR / Art. 28 tables in
// the DPA need this).
//
// All custom renderers map to Euphire tokens so legal pages feel like
// part of the marketing site, not raw HTML.

import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

export function MarkdownRenderer({ source }: { source: string }) {
  return (
    <div className="font-serif text-frost/85 leading-relaxed text-base">
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        components={{
          h2: ({ children }) => (
            <h2 className="font-display text-frost text-2xl sm:text-3xl font-semibold mt-10 mb-4 tracking-[var(--tracking-display)] scroll-mt-24">
              {children}
            </h2>
          ),
          h3: ({ children }) => (
            <h3 className="font-display text-frost text-xl font-semibold mt-6 mb-3">
              {children}
            </h3>
          ),
          p: ({ children }) => (
            <p className="my-3 leading-relaxed text-mist">{children}</p>
          ),
          ul: ({ children }) => (
            <ul className="my-4 space-y-2 list-disc list-outside pl-6 text-mist">
              {children}
            </ul>
          ),
          ol: ({ children }) => (
            <ol className="my-4 space-y-2 list-decimal list-outside pl-6 text-mist">
              {children}
            </ol>
          ),
          li: ({ children }) => <li className="leading-relaxed">{children}</li>,
          a: ({ href, children }) => (
            <a
              href={href}
              className="text-ember hover:underline underline-offset-2"
            >
              {children}
            </a>
          ),
          strong: ({ children }) => (
            <strong className="text-frost font-semibold">{children}</strong>
          ),
          code: ({ children }) => (
            <code className="font-mono text-[0.85em] px-1 py-0.5 rounded bg-frost/10 text-frost">
              {children}
            </code>
          ),
          blockquote: ({ children }) => (
            <blockquote className="my-5 border-l-2 border-ember/60 bg-frost/[0.04] px-4 py-3 rounded-r text-mist">
              {children}
            </blockquote>
          ),
          table: ({ children }) => (
            <div className="my-5 overflow-x-auto">
              <table className="w-full text-sm border-collapse">{children}</table>
            </div>
          ),
          thead: ({ children }) => <thead className="bg-frost/5">{children}</thead>,
          th: ({ children }) => (
            <th className="text-left font-mono uppercase text-[10px] tracking-[var(--tracking-label)] text-mist px-3 py-2 border-b border-frost/10">
              {children}
            </th>
          ),
          td: ({ children }) => (
            <td className="px-3 py-2 border-b border-frost/5 text-mist align-top">
              {children}
            </td>
          ),
          hr: () => <hr className="my-8 border-frost/10" />,
        }}
      >
        {source}
      </ReactMarkdown>
    </div>
  );
}
