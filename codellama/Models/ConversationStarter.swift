//
//  ConversationStarter.swift
//  codellama
//
//  Created by Codex on 3/15/26.
//

import Foundation

struct ConversationStarter: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let prompt: String
    let systemImage: String
    let category: String
}

extension ConversationStarter {
    static let all: [ConversationStarter] = [
        ConversationStarter(
            id: "debug-production-issue",
            title: "Help me debug a production issue step by step.",
            prompt: "I need help debugging a production issue. Ask me the key questions, help me narrow down root causes, and propose a structured fix plan.",
            systemImage: "ladybug",
            category: "Developer"
        ),
        ConversationStarter(
            id: "build-feature-spec",
            title: "Turn a rough idea into a product spec.",
            prompt: "Help me turn a rough product idea into a concise spec with goals, scope, edge cases, and acceptance criteria.",
            systemImage: "doc.text.magnifyingglass",
            category: "Product"
        ),
        ConversationStarter(
            id: "review-pull-request",
            title: "Review a pull request for bugs and regressions.",
            prompt: "Review this change like a senior engineer. Focus on bugs, regressions, missing tests, and risky assumptions.",
            systemImage: "checklist",
            category: "Developer"
        ),
        ConversationStarter(
            id: "plan-refactor",
            title: "Create a safe refactor plan for this codebase.",
            prompt: "Help me plan a safe refactor. Break it into steps, identify risks, and define how to verify behavior after each step.",
            systemImage: "arrow.triangle.branch",
            category: "Developer"
        ),
        ConversationStarter(
            id: "learn-concept",
            title: "Teach me a complex topic from first principles.",
            prompt: "Teach me this topic from first principles. Start simple, build up gradually, and include examples and checkpoints.",
            systemImage: "graduationcap",
            category: "Learning"
        ),
        ConversationStarter(
            id: "study-plan",
            title: "Make me a practical study plan for a new skill.",
            prompt: "Create a practical study plan for learning a new skill. Organize it week by week with milestones, exercises, and review points.",
            systemImage: "calendar.badge.clock",
            category: "Learning"
        ),
        ConversationStarter(
            id: "research-brief",
            title: "Summarize a topic like a research assistant.",
            prompt: "Act like a research assistant. Help me gather the important angles on a topic, summarize them clearly, and highlight open questions.",
            systemImage: "books.vertical",
            category: "Research"
        ),
        ConversationStarter(
            id: "compare-options",
            title: "Compare several options and recommend one.",
            prompt: "Compare a few options for me. Use criteria, tradeoffs, and a final recommendation with reasoning.",
            systemImage: "scale.3d",
            category: "Decision Making"
        ),
        ConversationStarter(
            id: "write-email",
            title: "Draft a thoughtful email or message.",
            prompt: "Help me draft a clear, thoughtful message. I want a version that sounds natural, concise, and appropriate for the audience.",
            systemImage: "envelope.open",
            category: "Writing"
        ),
        ConversationStarter(
            id: "rewrite-tone",
            title: "Rewrite something for a different tone or audience.",
            prompt: "Rewrite this for a different audience and tone. Keep the meaning, but improve clarity and make it fit the new context.",
            systemImage: "text.redaction",
            category: "Writing"
        ),
        ConversationStarter(
            id: "brainstorm-campaign",
            title: "Brainstorm a campaign or growth idea.",
            prompt: "Brainstorm a set of strong campaign or growth ideas. Organize them by audience, message, and likely effort.",
            systemImage: "megaphone",
            category: "Marketing"
        ),
        ConversationStarter(
            id: "improve-landing-page",
            title: "Audit a landing page for clarity and conversion.",
            prompt: "Review my landing page copy and structure. Suggest ways to improve clarity, trust, and conversion.",
            systemImage: "rectangle.and.text.magnifyingglass",
            category: "Marketing"
        ),
        ConversationStarter(
            id: "customer-support",
            title: "Draft a better support reply for a customer.",
            prompt: "Help me draft a support response that is empathetic, direct, and useful. Include a short and a detailed version.",
            systemImage: "person.crop.circle.badge.questionmark",
            category: "Support"
        ),
        ConversationStarter(
            id: "meeting-agenda",
            title: "Turn a messy topic into a strong meeting agenda.",
            prompt: "Create a focused meeting agenda from this messy topic. Include objectives, discussion flow, and next-decision prompts.",
            systemImage: "list.bullet.rectangle",
            category: "Work"
        ),
        ConversationStarter(
            id: "meeting-summary",
            title: "Convert notes into a clean summary and action list.",
            prompt: "Turn these notes into a clean summary with key decisions, open questions, and action items with owners.",
            systemImage: "note.text",
            category: "Work"
        ),
        ConversationStarter(
            id: "project-plan",
            title: "Build a project plan with milestones and risks.",
            prompt: "Help me build a project plan with milestones, dependencies, risks, and a realistic execution order.",
            systemImage: "timeline.selection",
            category: "Planning"
        ),
        ConversationStarter(
            id: "founder-priorities",
            title: "Help me decide what to focus on next in my business.",
            prompt: "I need help deciding what to focus on next in my business. Help me prioritize using impact, urgency, and effort.",
            systemImage: "briefcase",
            category: "Founder"
        ),
        ConversationStarter(
            id: "ops-checklist",
            title: "Create an operations checklist for a recurring process.",
            prompt: "Create an operations checklist for a recurring process. Make it easy to follow, verify, and hand off to someone else.",
            systemImage: "checkmark.square",
            category: "Operations"
        ),
        ConversationStarter(
            id: "job-application",
            title: "Improve my resume or job application materials.",
            prompt: "Help me improve my resume or application materials. Focus on clarity, impact, and tailoring for the role.",
            systemImage: "person.text.rectangle",
            category: "Career"
        ),
        ConversationStarter(
            id: "interview-practice",
            title: "Run a mock interview with me.",
            prompt: "Run a mock interview with me. Ask one question at a time, then critique my answers and help me improve.",
            systemImage: "person.2.wave.2",
            category: "Career"
        ),
        ConversationStarter(
            id: "design-critique",
            title: "Critique a design idea and suggest improvements.",
            prompt: "Critique this design idea. Point out usability issues, missing states, and ways to improve visual hierarchy and clarity.",
            systemImage: "paintbrush.pointed",
            category: "Design"
        ),
        ConversationStarter(
            id: "creative-brief",
            title: "Turn a vague brief into a sharper creative direction.",
            prompt: "Help me sharpen this creative brief. Clarify the audience, tone, concept direction, and what strong execution would look like.",
            systemImage: "sparkles.rectangle.stack",
            category: "Design"
        ),
        ConversationStarter(
            id: "content-outline",
            title: "Create an outline for an article, talk, or post.",
            prompt: "Create a strong outline for this article, talk, or post. Organize the main points, flow, and supporting examples.",
            systemImage: "text.alignleft",
            category: "Writing"
        ),
        ConversationStarter(
            id: "family-trip",
            title: "Plan a family trip with tradeoffs and budget in mind.",
            prompt: "Help me plan a family trip. Compare options, estimate budget, and suggest a simple itinerary that fits our constraints.",
            systemImage: "airplane",
            category: "Personal"
        ),
        ConversationStarter(
            id: "meal-plan",
            title: "Make me a practical meal plan for the week.",
            prompt: "Create a practical meal plan for the week based on my goals, time constraints, and ingredients I already have.",
            systemImage: "fork.knife",
            category: "Personal"
        ),
        ConversationStarter(
            id: "finance-plan",
            title: "Help me make sense of a personal budgeting goal.",
            prompt: "Help me think through a personal budgeting goal. Break it into categories, tradeoffs, and a realistic plan.",
            systemImage: "creditcard",
            category: "Personal"
        ),
        ConversationStarter(
            id: "life-admin",
            title: "Organize a pile of life admin into next actions.",
            prompt: "I have too many personal admin tasks. Help me organize them into clear next actions, grouped by urgency and effort.",
            systemImage: "tray.full",
            category: "Personal"
        ),
        ConversationStarter(
            id: "health-questions",
            title: "Prepare better questions for a doctor or specialist.",
            prompt: "Help me prepare for a medical appointment by organizing my observations and turning them into clear questions to ask.",
            systemImage: "cross.case",
            category: "Personal"
        ),
        ConversationStarter(
            id: "home-project",
            title: "Plan a home project from idea to checklist.",
            prompt: "Help me plan a home project. Break it into steps, materials, budget, and what could go wrong.",
            systemImage: "house",
            category: "Personal"
        ),
        ConversationStarter(
            id: "decision-journal",
            title: "Help me think through an important personal decision.",
            prompt: "Help me think through an important decision. Structure the tradeoffs, surface blind spots, and suggest a decision framework.",
            systemImage: "compass.drawing",
            category: "Decision Making"
        ),
        ConversationStarter(
            id: "agent-workflow",
            title: "Design a workflow where an AI agent can save me time.",
            prompt: "Help me identify repetitive work I do and design an AI-agent workflow that could automate or accelerate it safely.",
            systemImage: "cpu",
            category: "AI Workflow"
        )
    ]
}
