// @ts-nocheck
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import OpenAI from "https://esm.sh/openai";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

console.info("server started");

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });
  }

  try {
    const {
      apiKey,
      baseUrl,
      model,
      holdingsData,
      messages,
    }: {
      apiKey: string;
      baseUrl: string;
      model: string;
      holdingsData: string;
      messages: {
        role: string;
        content: string;
      }[];
    } = await req.json();

    // limit messages to last 10
    const limitedMessages = messages.slice(-10);

    // create prompt for LLM
    const openai = new OpenAI({
      baseURL: baseUrl,
      apiKey: apiKey,
    });

    const chatCompletion = await openai.chat.completions.create({
      model: model,
      messages: [
        {
          role: "system",
          content: `
            ข้อมูล Portfolio ของผู้ใช้: \n${holdingsData}\n 
            การตอบหข้อมูลที่เป็นตารางให้ใช้ bullet points แทนการใช้ table เพื่อให้แสดงผลได้ดีใน mobile`,
        },
        ...limitedMessages,
      ],
    });

    const reply = chatCompletion.choices[0].message;

    // return response
    return new Response(
      JSON.stringify({
        reply: reply,
        limitedMessages: limitedMessages,
      }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
          Connection: "keep-alive",
        },
      },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : "Unknown error",
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }
});
