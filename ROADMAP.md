# 🚀 Extractor Application Roadmap

**Vision:** Transform a personal LLM-powered test generation tool into a production-ready, scalable NPM package that empowers educators and developers worldwide.

---

## 📊 Current State Analysis

### ✅ What Works Well
- Multi-agent parallel processing with Gemini CLI
- PDF to test question generation pipeline
- Validation and merging capabilities
- File locking and queue management
- Configurable categories and batch sizes

### ⚠️ Current Limitations
- Bash/Gemini CLI dependency (not portable)
- Manual configuration required
- No cross-platform compatibility
- Single-user focused
- No programmatic API
- Hard-coded paths and configurations
- Limited error recovery

---

## 🎯 Roadmap Phases

### **Phase 1: Foundation & Stabilization** (Months 1-2)
*Goal: Fix critical issues and establish a solid foundation*

#### 1.1 Critical Bug Fixes
- [ ] **Cross-platform path compatibility**
  - Replace Windows-specific paths with environment variables
  - Support Linux, macOS, and Windows
  - Add path validation on startup

- [ ] **Rate limit handling improvements**
  - Implement global pause flag mechanism (`.pause.flag`)
  - Add exponential backoff retry logic
  - Smart queue management during rate limits

- [ ] **Progress tracking accuracy**
  - Exclude `_UNCOMPLETED.json` from completion counts
  - Add detailed progress reporting
  - Track partial completions

- [ ] **Intelligent retry mechanism**
  - Auto-requeue failed files with retry counter
  - Configurable max retry attempts
  - Failed file analysis and reporting

#### 1.2 Configuration Management
- [ ] **Centralized configuration system**
  - Create `extractor.config.json` (or YAML)
  - Environment variable support
  - Configuration validation
  - Example configurations for common use cases

```json
{
  "directories": {
    "input": "./inputs",
    "output": "./outputs",
    "done": "./done",
    "failed": "./failed",
    "waitingRoom": "./waiting_room"
  },
  "processing": {
    "maxAgents": 3,
    "batchSize": 3,
    "retryAttempts": 3,
    "questionsPerDocument": 50
  },
  "llm": {
    "provider": "gemini",
    "model": "gemini-1.5-pro",
    "apiKey": "${GEMINI_API_KEY}",
    "rateLimit": {
      "requestsPerMinute": 10,
      "backoffStrategy": "exponential"
    }
  }
}
```

#### 1.3 Logging & Monitoring
- [ ] **Structured logging system**
  - JSON-formatted logs for parsing
  - Log levels (DEBUG, INFO, WARN, ERROR)
  - Separate logs by agent/process
  - Log rotation and cleanup

- [ ] **Dashboard/CLI status viewer**
  - Real-time progress tracking
  - Agent status visualization
  - Queue statistics
  - Error summaries

---

### **Phase 2: Core Feature Enhancements** (Months 3-4)
*Goal: Make the application more powerful and user-friendly*

#### 2.1 Enhanced Question Generation
- [ ] **Multiple question types support**
  - Multiple choice (current)
  - True/False
  - Fill in the blank
  - Short answer
  - Matching questions
  - Essay prompts

- [ ] **Difficulty level classification**
  - Auto-classify: Easy, Medium, Hard
  - Bloom's Taxonomy levels
  - Adaptive difficulty based on content

- [ ] **Question metadata enrichment**
  - Tags and keywords
  - Learning objectives mapping
  - Estimated time to complete
  - Topic/chapter references

#### 2.2 Quality Improvements
- [ ] **Advanced validation system**
  - Duplicate detection (semantic, not just exact)
  - Grammar and spelling checks
  - Answer plausibility verification
  - Question clarity scoring

- [ ] **Quality metrics dashboard**
  - Questions per document statistics
  - Validation pass/fail rates
  - Category coverage analysis
  - Quality score distribution

#### 2.3 Input Format Support
- [ ] **Multiple input formats**
  - PDF (current)
  - DOCX/DOC
  - TXT
  - EPUB
  - HTML/Markdown
  - Audio transcripts (via Whisper integration)

- [ ] **OCR improvements**
  - Better image extraction from PDFs
  - Table recognition
  - Diagram/chart understanding
  - Handwriting recognition

---

### **Phase 3: Node.js/TypeScript Migration** (Months 5-6)
*Goal: Transform into a professional Node.js application*

#### 3.1 Core Application Rewrite
- [ ] **TypeScript-based architecture**
  - Type-safe configuration
  - Robust error handling
  - Modern async/await patterns
  - Plugin system architecture

- [ ] **Project structure**
```
extractor/
├── src/
│   ├── core/
│   │   ├── pipeline.ts        # Main processing pipeline
│   │   ├── agent.ts           # Agent orchestration
│   │   ├── queue.ts           # Queue management
│   │   └── config.ts          # Configuration loader
│   ├── processors/
│   │   ├── pdf.ts             # PDF processing
│   │   ├── docx.ts            # Word processing
│   │   └── text.ts            # Plain text processing
│   ├── generators/
│   │   ├── llm-client.ts      # LLM abstraction
│   │   ├── question-gen.ts    # Question generation
│   │   └── validator.ts       # Validation logic
│   ├── storage/
│   │   ├── file-store.ts      # File-based storage
│   │   ├── db-store.ts        # Database storage
│   │   └── cache.ts           # Caching layer
│   ├── cli/
│   │   ├── commands/          # CLI commands
│   │   └── ui/                # Terminal UI components
│   └── api/
│       ├── server.ts          # REST API server
│       └── routes/            # API routes
├── tests/
├── docs/
├── examples/
└── package.json
```

#### 3.2 Multi-LLM Provider Support
- [ ] **Provider abstraction layer**
  - OpenAI (GPT-4, GPT-3.5)
  - Anthropic (Claude)
  - Google (Gemini)
  - Local models (Ollama, LM Studio)
  - Custom API endpoints

- [ ] **Cost optimization**
  - Provider cost comparison
  - Automatic fallback on rate limits
  - Cost tracking per operation
  - Budget alerts

#### 3.3 CLI Improvements
- [ ] **Modern CLI with Commander.js**
```bash
extractor generate --input ./books --category science --output ./tests
extractor validate --source ./books/chapter1.pdf --tests ./tests/chapter1.json
extractor merge --category science --output ./final/science-tests.json
extractor status --watch  # Real-time status monitoring
extractor config init     # Initialize configuration
```

- [ ] **Interactive prompts**
  - Guided setup wizard
  - File/folder selection UI
  - Progress bars and spinners
  - Colored output for readability

---

### **Phase 4: NPM Package Development** (Months 7-8)
*Goal: Prepare for public distribution*

#### 4.1 Package Configuration
- [ ] **NPM package setup**
  - Publish to npm registry
  - Semantic versioning
  - Change log automation
  - CI/CD pipeline (GitHub Actions)

- [ ] **Package.json essentials**
```json
{
  "name": "@yourname/extractor",
  "version": "1.0.0",
  "description": "AI-powered test question generator from educational materials",
  "main": "dist/index.js",
  "bin": {
    "extractor": "dist/cli/index.js"
  },
  "scripts": {
    "build": "tsc",
    "test": "jest",
    "lint": "eslint src/**/*.ts",
    "prepublishOnly": "npm run build && npm test"
  },
  "keywords": [
    "education",
    "test-generation",
    "llm",
    "ai",
    "quiz",
    "learning"
  ]
}
```

#### 4.2 Programmatic API
- [ ] **Clean JavaScript/TypeScript API**
```typescript
import { Extractor, QuestionGenerator } from '@yourname/extractor';

// Simple usage
const extractor = new Extractor({
  llm: { provider: 'openai', apiKey: process.env.OPENAI_API_KEY },
  output: './tests'
});

await extractor.processFile('./book.pdf', {
  category: 'science',
  questionCount: 50,
  difficulty: ['medium', 'hard']
});

// Advanced usage with custom pipeline
const generator = new QuestionGenerator({
  llm: { provider: 'claude' },
  validators: [
    new GrammarValidator(),
    new DuplicateValidator(),
    new FactChecker()
  ]
});

const questions = await generator.generate({
  input: './chapter1.pdf',
  type: ['multiple-choice', 'true-false'],
  metadata: { chapter: 1, topic: 'Biology' }
});
```

#### 4.3 Documentation
- [ ] **Comprehensive documentation**
  - Getting started guide
  - API reference (auto-generated from TSDoc)
  - Configuration guide
  - Best practices
  - Troubleshooting guide
  - FAQ section

- [ ] **Interactive documentation site**
  - Built with Docusaurus or VitePress
  - Live code examples
  - Video tutorials
  - Community showcase

#### 4.4 Examples & Templates
- [ ] **Example projects**
  - Simple CLI usage
  - Node.js integration
  - Express.js API server
  - Next.js web application
  - Electron desktop app

---

### **Phase 5: Advanced Features** (Months 9-11)
*Goal: Add enterprise-grade capabilities*

#### 5.1 Database Integration
- [ ] **Persistent storage options**
  - SQLite (default, file-based)
  - PostgreSQL
  - MongoDB
  - MySQL

- [ ] **Question bank management**
  - CRUD operations for questions
  - Version control for questions
  - Full-text search
  - Advanced filtering and querying

#### 5.2 Web API & Dashboard
- [ ] **REST API server**
```typescript
POST   /api/v1/extract        # Start extraction job
GET    /api/v1/jobs/:id       # Get job status
GET    /api/v1/questions      # List questions
POST   /api/v1/validate       # Validate questions
POST   /api/v1/merge          # Merge question sets
DELETE /api/v1/questions/:id  # Delete question
```

- [ ] **Web-based dashboard**
  - Job management interface
  - Question preview and editing
  - Analytics and reporting
  - User management (multi-tenant)

#### 5.3 Export Formats
- [ ] **Multiple export formats**
  - JSON (current)
  - CSV
  - Excel (XLSX)
  - Moodle XML
  - GIFT format (for LMS)
  - Anki deck format
  - Google Forms
  - Kahoot import format

#### 5.4 Collaboration Features
- [ ] **Multi-user support**
  - User authentication
  - Role-based access control
  - Team workspaces
  - Shared question banks

- [ ] **Review workflow**
  - Question approval process
  - Comments and feedback
  - Version history
  - Collaborative editing

#### 5.5 AI Enhancements
- [ ] **Smart features**
  - Auto-categorization using embeddings
  - Similar question detection
  - Question recommendation system
  - Automatic distractor generation (wrong answers)
  - Answer explanation generation

---

### **Phase 6: Scaling & Distribution** (Months 12+)
*Goal: Enterprise-ready and cloud-native*

#### 6.1 Performance Optimization
- [ ] **High-performance processing**
  - Parallel processing with worker threads
  - Streaming for large files
  - Caching layer (Redis)
  - Background job processing (Bull/BullMQ)

- [ ] **Resource management**
  - Memory usage optimization
  - CPU usage throttling
  - Disk space monitoring
  - Network bandwidth management

#### 6.2 Cloud Deployment
- [ ] **Docker support**
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY dist ./dist
CMD ["node", "dist/cli/index.js", "serve"]
```

- [ ] **Kubernetes deployment**
  - Helm charts
  - Auto-scaling policies
  - Health checks and monitoring
  - Distributed processing

- [ ] **Serverless support**
  - AWS Lambda functions
  - Google Cloud Functions
  - Azure Functions
  - Vercel/Netlify edge functions

#### 6.3 SaaS Platform
- [ ] **Commercial offering**
  - Hosted service (extractor.io)
  - Subscription tiers (Free, Pro, Enterprise)
  - Usage-based billing
  - API rate limiting

- [ ] **Enterprise features**
  - SSO integration (SAML, OAuth)
  - Audit logging
  - Compliance certifications
  - Custom deployments
  - SLA guarantees

#### 6.4 Marketplace & Ecosystem
- [ ] **Plugin marketplace**
  - Custom processors
  - LLM providers
  - Validators
  - Export formats
  - UI themes

- [ ] **Community contributions**
  - Public plugin registry
  - Template library
  - Integration partners
  - Developer grants program

---

## 🎨 Key Features That Make Customers Tick

### For Educators
1. **One-click test generation** - Upload a textbook, get hundreds of quality questions
2. **Instant validation** - Ensure all questions are factually correct
3. **Multiple export formats** - Compatible with all major LMS platforms
4. **Difficulty auto-detection** - Create balanced tests automatically
5. **Cost transparency** - Know exactly how much each test costs to generate

### For Developers
1. **Simple npm install** - No complex setup required
2. **5-minute integration** - Add AI test generation to any app
3. **Provider agnostic** - Use any LLM (OpenAI, Claude, local models)
4. **Type-safe API** - Full TypeScript support
5. **Extensible architecture** - Build custom processors and validators

### For Enterprises
1. **Scalable processing** - Handle thousands of documents
2. **Team collaboration** - Multi-user workspaces and review workflows
3. **Security & compliance** - Enterprise-grade security features
4. **Self-hosting option** - Deploy on your own infrastructure
5. **Priority support** - Dedicated support team

---

## 📈 Success Metrics

### Technical Metrics
- **Processing speed:** < 30 seconds per page
- **Accuracy rate:** > 95% validation pass rate
- **API uptime:** 99.9% SLA
- **NPM downloads:** 10,000+ per month (Year 1)

### Business Metrics
- **GitHub stars:** 1,000+ (Year 1)
- **Active users:** 5,000+ (Year 1)
- **Paid subscribers:** 100+ (Year 1)
- **Revenue:** $10,000 MRR (Year 2)

### Community Metrics
- **Contributors:** 20+ active contributors
- **Plugins:** 50+ community plugins
- **Integrations:** 10+ official integrations
- **Documentation views:** 50,000+ per month

---

## 🛠️ Technology Stack Recommendations

### Core Application
- **Language:** TypeScript 5.x
- **Runtime:** Node.js 20 LTS
- **CLI Framework:** Commander.js + Inquirer.js
- **Testing:** Jest + Playwright
- **Build:** tsup or esbuild

### File Processing
- **PDF:** pdf-parse, pdfjs-dist
- **DOCX:** mammoth, docx
- **OCR:** Tesseract.js
- **Text extraction:** unified, remark

### LLM Integration
- **Multi-provider:** LangChain or custom abstraction
- **Rate limiting:** bottleneck
- **Retries:** p-retry
- **Streaming:** streaming-iterables

### Storage
- **Default:** SQLite (better-sqlite3)
- **Advanced:** TypeORM or Prisma (multi-DB support)
- **Cache:** node-cache or Redis

### API & Web
- **API Framework:** Express.js or Fastify
- **Validation:** Zod or Joi
- **API docs:** OpenAPI/Swagger
- **Dashboard:** React + Vite + shadcn/ui

### DevOps
- **CI/CD:** GitHub Actions
- **Containerization:** Docker + Docker Compose
- **Package management:** npm or pnpm
- **Version control:** Semantic Release

---

## 🚦 Implementation Priority Matrix

### Must Have (P0) - Phase 1-3
- Cross-platform compatibility
- Rate limit handling
- Configuration system
- TypeScript migration
- Basic CLI
- NPM package setup

### Should Have (P1) - Phase 4-5
- Multi-LLM support
- Database integration
- Web API
- Export formats
- Documentation site

### Nice to Have (P2) - Phase 6
- Web dashboard
- Cloud deployment
- Plugin marketplace
- SaaS platform

---

## 📝 Next Steps

### Immediate Actions (This Week)
1. Fix critical path issues (Phase 1.1)
2. Create centralized configuration (Phase 1.2)
3. Set up GitHub issues for roadmap tracking
4. Create project structure for TypeScript migration

### Month 1 Goals
1. Complete Phase 1 (Foundation & Stabilization)
2. Begin Phase 2 (Core Feature Enhancements)
3. Set up development environment for TypeScript
4. Write initial tests for core functionality

### Quarter 1 Goals (Months 1-3)
1. Complete Phases 1-2
2. Start Phase 3 (TypeScript migration)
3. Release v0.1.0-alpha to npm
4. Gather feedback from early adopters

---

## 🤝 Contributing & Community

### Open Source Strategy
- **License:** MIT (developer-friendly)
- **Contributing guide:** Clear guidelines for PRs
- **Code of conduct:** Welcoming community standards
- **Issue templates:** Bug reports, feature requests
- **Discussions:** GitHub Discussions for Q&A

### Community Building
- **Discord server** for real-time chat
- **Monthly community calls**
- **Blog with tutorials and case studies**
- **Twitter/X for updates and tips**
- **YouTube channel for video tutorials**

---

## 💰 Monetization Strategy (Optional)

### Open Source Core + Premium Features
- **Free tier:** Core functionality, CLI, basic API
- **Pro tier ($29/mo):** Advanced features, priority support, higher rate limits
- **Enterprise tier ($299/mo):** Self-hosting, SSO, SLA, custom integrations
- **Cloud credits:** Bundled LLM API credits at discounted rates

### Alternative Models
- **Freemium SaaS:** Free for small projects, paid for scale
- **Marketplace revenue share:** 20% commission on paid plugins
- **Consulting services:** Custom implementations and training
- **Sponsorships:** GitHub Sponsors + Open Collective

---

## 📚 Resources & References

### Inspiration & Competition Analysis
- **Quizlet** - AI-powered flashcard generation
- **Kahoot** - Interactive quiz platform
- **Anki** - Spaced repetition system
- **Google Forms** - Survey and quiz builder
- **Moodle** - Open source LMS

### Technical Resources
- [LangChain Documentation](https://js.langchain.com)
- [OpenAI API Best Practices](https://platform.openai.com/docs/guides/best-practices)
- [Node.js Best Practices](https://github.com/goldbergyoni/nodebestpractices)
- [npm Package Publishing Guide](https://docs.npmjs.com/packages-and-modules)

---

**Last Updated:** 2025-11-05
**Document Version:** 1.0
**Maintained By:** wujekbizon

---

## Appendix A: Feature Comparison Matrix

| Feature | Current | v1.0 | v2.0 | Enterprise |
|---------|---------|------|------|------------|
| PDF Processing | ✅ | ✅ | ✅ | ✅ |
| Multi-format Input | ❌ | ✅ | ✅ | ✅ |
| Multiple Choice Q's | ✅ | ✅ | ✅ | ✅ |
| Other Question Types | ❌ | ✅ | ✅ | ✅ |
| CLI Interface | ✅ | ✅ | ✅ | ✅ |
| Programmatic API | ❌ | ✅ | ✅ | ✅ |
| Web Dashboard | ❌ | ❌ | ✅ | ✅ |
| Multi-LLM Support | ⚠️ | ✅ | ✅ | ✅ |
| Database Storage | ❌ | ❌ | ✅ | ✅ |
| Export Formats | JSON | JSON, CSV, GIFT | All formats | All + Custom |
| Team Collaboration | ❌ | ❌ | ✅ | ✅ |
| SSO Integration | ❌ | ❌ | ❌ | ✅ |
| Self-hosting | ✅ | ✅ | ✅ | ✅ |
| Cloud Hosting | ❌ | ❌ | ✅ | ✅ |
| Plugin System | ❌ | ❌ | ✅ | ✅ |

✅ = Included | ⚠️ = Partial | ❌ = Not included

---

*This roadmap is a living document and will be updated as the project evolves.*
