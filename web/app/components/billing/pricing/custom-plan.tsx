import React, { useState, useEffect, useRef } from 'react'
import type { FC, ReactNode } from 'react'
import { RiApps2Line, RiGroupLine, RiHardDrive3Line, RiQuestionLine, RiRssLine, RiSpeedUpLine } from '@remixicon/react'
import useSWRMutation from 'swr/mutation'
import Toast from '../../base/toast'
import type { CustomPlanResponse, PayRequestResponse } from '@/models/common'
import { post, get } from '@/service/base'
import { useAppContext } from '@/context/app-context'
import Tooltip from '../../base/tooltip'
import Divider from '../../base/divider'
import Button from '../../base/button'
import cn from '@/utils/classnames'

type Props = { plan: CustomPlanResponse }

const payRequestFetcher = (url: string, { arg }: { arg: { id_plan: number; id_account: string } }) => {
  return post<PayRequestResponse>(url, { body: arg })
}

const KeyValue: FC<{ icon: ReactNode; label: string | ReactNode; tooltip?: ReactNode }> = ({ icon, label, tooltip }) => {
  return (
    <div className='flex items-center text-text-tertiary'>
      <div className='flex size-4 items-center justify-center text-util-colors-blue-brand-blue-brand-600'>
        {icon}
      </div>
      <div className='system-sm-regular ml-2 mr-0.5 text-text-primary'>{label}</div>
      {tooltip && (
        <Tooltip
          asChild
          popupContent={tooltip}
          popupClassName='w-[200px]'
        >
          <div className='flex size-4 items-center justify-center'>
            <RiQuestionLine className='text-text-quaternary' />
          </div>
        </Tooltip>
      )}
    </div>
  )
}

const CustomPlan: FC<Props> = ({ plan }) => {
  const { userProfile, mutateUserProfile } = useAppContext()
  const currentPlanId = userProfile.id_custom_plan
  const planExpiration = userProfile.plan_expiration
  const isCurrent = String(plan.id) === currentPlanId
  const [qrUrl, setQrUrl] = useState<string>()
  const [isQrModalOpen, setIsQrModalOpen] = useState(false)
  const [currentAlies, setCurrentAlies] = useState<string | null>(null)
  const intervalRef = useRef<NodeJS.Timeout | null>(null)

  const { trigger, isMutating } = useSWRMutation('/custom/pay_request', payRequestFetcher)

  const stopPolling = () => {
    if (intervalRef.current) {
      clearInterval(intervalRef.current)
      intervalRef.current = null
    }
  }

  useEffect(() => {
    if (isQrModalOpen && currentAlies && userProfile?.id) {
      intervalRef.current = setInterval(async () => {
        try {
          const url = `/custom/pay_request/${userProfile.id}`
          const result = await get<{ status: string; message: string; alies?: string }>(url)

          if (result.status === 'success' && result.alies === currentAlies) {
            console.log('Payment pending, alies matches.')
            return
          } else if (result.status === 'success' && result.alies !== currentAlies) {
            console.error('Alies mismatch. Stopping poll.')
            Toast.notify({ type: 'error', message: 'Alies không khớp.' })
            stopPolling()
            setIsQrModalOpen(false)
          } else if (result.status === 'success') {
            console.warn('Unexpected success response format:', result)
          } else {
            console.error('Unexpected status:', result.status, result.message)
            Toast.notify({ type: 'error', message: result.message || 'Kiểm tra thanh toán thất bại.' })
            stopPolling()
          }
        } catch (error: any) {
          if (error.status === 404) {
            console.log('Payment likely successful (404). Stopping poll.')
            Toast.notify({ type: 'success', message: 'Thanh toán thành công.' })
            stopPolling()
            setIsQrModalOpen(false)
            mutateUserProfile()
            // Reload the page to reflect the new plan status
            window.location.reload()
          } else {
            console.error('Error checking payment status:', error)
            Toast.notify({ type: 'error', message: error.message || 'Kiểm tra thanh toán thất bại.' })
            stopPolling()
          }
        }
      }, 5000)
    } else {
      stopPolling()
    }

    return () => {
      stopPolling()
    }
  }, [isQrModalOpen, currentAlies, userProfile?.id, mutateUserProfile])

  const handlePay = async () => {
    if (isMutating || isCurrent) return
    setQrUrl(undefined)
    setCurrentAlies(null)
    stopPolling()
    try {
      const result = await trigger({ id_plan: plan.id, id_account: userProfile.id })
      if (result && result.status === 'success' && typeof result.url === 'string' && typeof result.alies === 'string') {
        setQrUrl(result.url)
        setCurrentAlies(result.alies)
        setIsQrModalOpen(true)
      } else {
        Toast.notify({ type: 'error', message: result?.message || 'Thiếu URL thanh toán.' })
      }
    } catch (error: any) {
      Toast.notify({ type: 'error', message: error.message || 'Yêu cầu thanh toán thất bại.' })
    }
  }

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat('vi-VN').format(price)
  }

  const formatDate = (dateString: string | undefined) => {
    if (!dateString) return 'N/A'
    try {
      // Format string: 1747986975 unix timestamp in seconds
      // Convert to milliseconds
      const unixTimestamp = parseInt(dateString, 10) * 1000
      const date = new Date(unixTimestamp)
      return date.toLocaleDateString(undefined, { year: 'numeric', month: 'long', day: 'numeric' })
    } catch (e) {
      return 'Invalid Date'
    }
  }

  const handleCloseModal = () => {
    setIsQrModalOpen(false)
  }

  return (
    <>
      <div className={cn(
        'flex w-[373px] flex-col rounded-2xl border-[0.5px] border-effects-highlight-lightmode-off bg-background-section-burn p-6 transition-all duration-200 ease-in-out',
        isCurrent ? 'border-blue-600 shadow-lg' : 'hover:border-effects-highlight hover:shadow-lg hover:backdrop-blur-[5px]',
      )}>
        <div className='flex flex-col gap-y-1'>
          <div className='text-lg font-semibold uppercase leading-[125%] text-text-primary'>{plan.name}</div>
          <div className='system-sm-regular text-text-secondary'>{plan.description}</div>
        </div>

        <div className='my-5'>
          <div className='flex items-end'>
            <div className='leading-[125%] text-[28px] font-bold text-text-primary'>{formatPrice(plan.price)} VNĐ</div>
            <div className='ml-1 text-[14px] font-normal leading-normal text-text-tertiary'>
              / {plan.plan_expiration} ngày
            </div>
          </div>
          {isCurrent && planExpiration && (
            <div className='mt-1 text-xs text-text-secondary'>
              Ngày hết hạn gói: {formatDate(planExpiration)}
            </div>
          )}
        </div>

        <button
          className={cn(
            'flex h-[42px] items-center justify-center rounded-full px-5 py-3 text-base font-medium transition-colors duration-200 ease-in-out',
            isCurrent
              ? 'cursor-default bg-components-button-secondary-bg-disabled border border-components-button-secondary-border-disabled text-components-button-secondary-text-disabled'
              : 'cursor-pointer bg-components-button-primary-bg hover:bg-components-button-primary-bg-hover border border-components-button-primary-border text-components-button-primary-text',
            isMutating && 'opacity-70 cursor-wait',
          )}
          disabled={isCurrent || isMutating}
          onClick={handlePay}
        >
          {isCurrent
            ? 'Gói hiện tại'
            : isMutating
            ? 'Đang xử lý...'
            : 'Buy'}
        </button>

        <div className='mt-6 flex flex-col gap-y-3'>
          <KeyValue
            icon={<RiGroupLine />}
            label={`${plan.features.members} thành viên`}
          />
          <KeyValue
            icon={<RiApps2Line />}
            label={`${plan.features.apps} ứng dụng`}
          />
          <Divider bgStyle='gradient' />
          <KeyValue
            icon={<RiHardDrive3Line />}
            label={`${plan.features.vector_space}MB không gian vector`}
            tooltip={'Dung lượng lưu trữ vector (MB).'}
          />
          <KeyValue
            icon={<RiSpeedUpLine />}
            label={`${plan.features.documents_upload_quota} tải lên tài liệu`}
            tooltip={'Giới hạn số lượng tài liệu được tải lên.'}
          />
          <KeyValue
            icon={<RiRssLine />}
            label={`${plan.features.annotation_quota_limit} hạn mức chú thích`}
            tooltip={'Giới hạn số lượng chú thích.'}
          />
        </div>
      </div>

      {isQrModalOpen && qrUrl && (
        <div
          className='fixed inset-0 z-[1001] flex items-center justify-center bg-black/50 backdrop-blur-sm'
          onClick={handleCloseModal}
        >
          <div
            className='bg-white rounded-lg shadow-xl p-6 flex flex-col items-center max-w-[600px] w-full'
            onClick={e => e.stopPropagation()}
          >
            <h2 className='text-lg font-semibold mb-4 text-gray-900'>Quét mã để thanh toán</h2>
            <img
              className='mb-4'
              src={qrUrl}
              alt='Payment QR code'
            />
            <p className='text-sm text-gray-600 mb-4'>Vui lòng quét mã QR để thanh toán.</p>
            <p className='text-xs text-gray-500 mb-4'>Đang kiểm tra trạng thái thanh toán...</p>
            <Button onClick={handleCloseModal} className='w-full'>
              Đóng
            </Button>
          </div>
        </div>
      )}
    </>
  )
}

export default React.memo(CustomPlan)
