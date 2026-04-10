// @ts-nocheck
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from '@supabase/supabase-js'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

const bucketName = 'stock-logos'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    })
  }

  try {
    const { ticker, sourceUrl } = await req.json()

    if (!ticker || !sourceUrl) {
      return new Response(
        JSON.stringify({ error: 'ticker and sourceUrl are required' }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        },
      )
    }

    const sourceResponse = await fetch(sourceUrl)
    if (!sourceResponse.ok) {
      return new Response(
        JSON.stringify({ error: 'Failed to fetch source logo' }),
        {
          status: 502,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        },
      )
    }

    const contentType = sourceResponse.headers.get('content-type') ??
      'image/png'
    const extension = getExtension(contentType, sourceUrl)
    const path = `${ticker.toUpperCase()}.${extension}`
    const bytes = await sourceResponse.arrayBuffer()

    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: 'Missing Supabase env vars' }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        },
      )
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey)
    const { error } = await supabase.storage.from(bucketName).upload(
      path,
      bytes,
      {
        contentType,
        upsert: true,
      },
    )

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      })
    }

    const { data } = supabase.storage.from(bucketName).getPublicUrl(path)

    return new Response(
      JSON.stringify({
        path,
        publicUrl: data.publicUrl,
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      },
    )
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      },
    )
  }
})

function getExtension(contentType: string, sourceUrl: string) {
  if (contentType.includes('svg')) return 'svg'
  if (contentType.includes('webp')) return 'webp'
  if (contentType.includes('jpeg') || contentType.includes('jpg')) return 'jpg'
  if (contentType.includes('png')) return 'png'

  try {
    const pathname = new URL(sourceUrl).pathname.toLowerCase()
    const segments = pathname.split('.')
    const fromPath = segments.length > 1 ? segments.pop() : null
    if (fromPath && ['png', 'jpg', 'jpeg', 'webp', 'svg'].includes(fromPath)) {
      return fromPath === 'jpeg' ? 'jpg' : fromPath
    }
  } catch (_) {
    // Ignore malformed URLs and fall back to png.
  }

  return 'png'
}
