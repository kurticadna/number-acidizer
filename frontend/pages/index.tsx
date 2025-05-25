import Head from 'next/head'
import { NumberAcidizer } from '@/components/NumberAcidizer'

export default function Home() {
  return (
    <>
      <Head>
        <title>Number Acidizer</title>
      </Head>
      <NumberAcidizer></NumberAcidizer>
    </>
  )
}